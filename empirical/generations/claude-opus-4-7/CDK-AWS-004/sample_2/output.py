from aws_cdk import (
    Stack,
    Duration,
    RemovalPolicy,
    aws_sqs as sqs,
    aws_lambda as lambda_,
    aws_lambda_event_sources as lambda_events,
    aws_dynamodb as dynamodb,
    aws_iam as iam,
    aws_logs as logs,
    aws_cloudwatch as cloudwatch,
    aws_kms as kms,
)
from constructs import Construct


class EventDrivenStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Customer-managed KMS key for encryption at rest
        encryption_key = kms.Key(
            self,
            "EncryptionKey",
            description="CMK for SQS, DynamoDB, and Lambda env encryption",
            enable_key_rotation=True,
            removal_policy=RemovalPolicy.RETAIN,
            alias="alias/event-driven-stack",
        )

        # Dead Letter Queue
        dlq = sqs.Queue(
            self,
            "EventsDLQ",
            queue_name="events-dlq",
            encryption=sqs.QueueEncryption.KMS,
            encryption_master_key=encryption_key,
            retention_period=Duration.days(14),
            enforce_ssl=True,
        )

        # Main SQS Queue
        queue = sqs.Queue(
            self,
            "EventsQueue",
            queue_name="events-queue",
            encryption=sqs.QueueEncryption.KMS,
            encryption_master_key=encryption_key,
            visibility_timeout=Duration.seconds(180),
            retention_period=Duration.days(4),
            enforce_ssl=True,
            dead_letter_queue=sqs.DeadLetterQueue(
                max_receive_count=5,
                queue=dlq,
            ),
        )

        # DynamoDB Table
        table = dynamodb.Table(
            self,
            "EventsTable",
            table_name="events-table",
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
            time_to_live_attribute="ttl",
            deletion_protection=True,
        )

        # Lambda execution role with least privilege
        lambda_role = iam.Role(
            self,
            "ProcessorLambdaRole",
            assumed_by=iam.ServicePrincipal("lambda.amazonaws.com"),
            description="Execution role for event processor Lambda",
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name(
                    "service-role/AWSLambdaBasicExecutionRole"
                )
            ],
        )

        # Lambda function
        processor_fn = lambda_.Function(
            self,
            "ProcessorFunction",
            function_name="events-processor",
            runtime=lambda_.Runtime.PYTHON_3_12,
            architecture=lambda_.Architecture.ARM_64,
            handler="index.handler",
            code=lambda_.Code.from_inline(
                """
import json
import os
import time
import uuid
import boto3
from botocore.config import Config

TABLE_NAME = os.environ["TABLE_NAME"]
METRIC_NAMESPACE = os.environ.get("METRIC_NAMESPACE", "EventDriven/Processor")

ddb = boto3.resource("dynamodb", config=Config(retries={"max_attempts": 5, "mode": "standard"}))
cw = boto3.client("cloudwatch")
table = ddb.Table(TABLE_NAME)


def handler(event, context):
    processed = 0
    failures = []
    start = time.time()

    for record in event.get("Records", []):
        try:
            body = json.loads(record["body"])
            pk = body.get("pk") or body.get("id") or str(uuid.uuid4())
            sk = body.get("sk") or record.get("messageId")
            item = {
                "pk": pk,
                "sk": sk,
                "payload": body,
                "received_at": int(time.time()),
            }
            table.put_item(Item=item)
            processed += 1
        except Exception as e:
            print(f"Error processing record {record.get('messageId')}: {e}")
            failures.append({"itemIdentifier": record["messageId"]})

    duration_ms = (time.time() - start) * 1000.0
    try:
        cw.put_metric_data(
            Namespace=METRIC_NAMESPACE,
            MetricData=[
                {"MetricName": "MessagesProcessed", "Unit": "Count", "Value": processed},
                {"MetricName": "MessagesFailed", "Unit": "Count", "Value": len(failures)},
                {"MetricName": "ProcessingDuration", "Unit": "Milliseconds", "Value": duration_ms},
            ],
        )
    except Exception as e:
        print(f"Failed to publish metrics: {e}")

    return {"batchItemFailures": failures}
"""
            ),
            role=lambda_role,
            timeout=Duration.seconds(30),
            memory_size=512,
            reserved_concurrent_executions=50,
            environment={
                "TABLE_NAME": table.table_name,
                "METRIC_NAMESPACE": "EventDriven/Processor",
                "LOG_LEVEL": "INFO",
            },
            environment_encryption=enc