from aws_cdk import (
    Stack,
    Duration,
    RemovalPolicy,
    CfnOutput,
    aws_sqs as sqs,
    aws_lambda as _lambda,
    aws_dynamodb as dynamodb,
    aws_lambda_event_sources as lambda_event_sources,
    aws_logs as logs,
    aws_cloudwatch as cloudwatch,
    aws_iam as iam,
    aws_kms as kms,
)
from constructs import Construct


class EventDrivenStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Customer-managed KMS key for encryption at rest
        encryption_key = kms.Key(
            self,
            "EventDrivenKey",
            description="CMK for SQS and DynamoDB encryption",
            enable_key_rotation=True,
            removal_policy=RemovalPolicy.RETAIN,
            alias="alias/event-driven-stack",
        )

        # DynamoDB table
        table = dynamodb.Table(
            self,
            "EventsTable",
            partition_key=dynamodb.Attribute(
                name="pk", type=dynamodb.AttributeType.STRING
            ),
            sort_key=dynamodb.Attribute(
                name="sk", type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            encryption=dynamodb.TableEncryption.CUSTOMER_MANAGED,
            encryption_key=encryption_key,
            point_in_time_recovery=True,
            removal_policy=RemovalPolicy.RETAIN,
            deletion_protection=True,
            time_to_live_attribute="ttl",
            contributor_insights_enabled=True,
        )

        # Dead-letter queue
        dlq = sqs.Queue(
            self,
            "EventsDLQ",
            queue_name="events-dlq",
            retention_period=Duration.days(14),
            encryption=sqs.QueueEncryption.KMS,
            encryption_master_key=encryption_key,
            enforce_ssl=True,
        )

        # Main queue
        queue = sqs.Queue(
            self,
            "EventsQueue",
            queue_name="events-queue",
            visibility_timeout=Duration.seconds(180),
            retention_period=Duration.days(4),
            encryption=sqs.QueueEncryption.KMS,
            encryption_master_key=encryption_key,
            enforce_ssl=True,
            dead_letter_queue=sqs.DeadLetterQueue(
                max_receive_count=5,
                queue=dlq,
            ),
        )

        # Lambda execution role
        lambda_role = iam.Role(
            self,
            "ProcessorFunctionRole",
            assumed_by=iam.ServicePrincipal("lambda.amazonaws.com"),
            description="Execution role for SQS->DynamoDB processor",
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name(
                    "service-role/AWSLambdaBasicExecutionRole"
                ),
            ],
        )

        # Processor Lambda
        processor_fn = _lambda.Function(
            self,
            "ProcessorFunction",
            runtime=_lambda.Runtime.PYTHON_3_12,
            architecture=_lambda.Architecture.ARM_64,
            handler="handler.lambda_handler",
            code=_lambda.Code.from_inline(
                """
import json
import os
import time
import uuid
import boto3

dynamodb = boto3.resource("dynamodb")
cloudwatch = boto3.client("cloudwatch")
table = dynamodb.Table(os.environ["TABLE_NAME"])
NAMESPACE = os.environ.get("METRIC_NAMESPACE", "EventDriven/Processor")


def _emit_metric(name, value, unit="Count"):
    try:
        cloudwatch.put_metric_data(
            Namespace=NAMESPACE,
            MetricData=[{"MetricName": name, "Value": value, "Unit": unit}],
        )
    except Exception as e:
        print(f"Failed to emit metric {name}: {e}")


def lambda_handler(event, context):
    batch_item_failures = []
    processed = 0
    failed = 0
    start = time.time()

    for record in event.get("Records", []):
        message_id = record.get("messageId")
        try:
            body = json.loads(record["body"]) if record.get("body") else {}
            item = {
                "pk": str(body.get("pk", message_id)),
                "sk": str(body.get("sk", str(uuid.uuid4()))),
                "payload": body,
                "received_at": int(time.time()),
            }
            table.put_item(Item=item)
            processed += 1
        except Exception as e:
            print(f"Failed to process {message_id}: {e}")
            failed += 1
            batch_item_failures.append({"itemIdentifier": message_id})

    _emit_metric("MessagesProcessed", processed)
    _emit_metric("MessagesFailed", failed)
    _emit_metric("ProcessingDurationMs", (time.time() - start) * 1000, "Milliseconds")

    return {"batchItemFailures": batch_item_failures}
"""
            ),
            role=lambda_role,
            timeout=Duration.seconds(30),
            memory_size=512,
            reserved_concurrent_executions=20,
            log_retention=logs.RetentionDays.ONE_MONTH,
            tracing=_lambda.Tracing.ACTIVE,
            environment={
                "TABLE_NAME": table.table_name,
                "METRIC_NAMESPACE": "EventDriven/Processor",
                "POWERTOOLS_SERVICE_NA