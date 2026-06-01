from aws_cdk import (
    Stack,
    Duration,
    RemovalPolicy,
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

        # Dead-letter queue for failed message processing
        dlq = sqs.Queue(
            self,
            "EventDLQ",
            queue_name="event-processing-dlq",
            encryption=sqs.QueueEncryption.KMS,
            encryption_master_key=encryption_key,
            retention_period=Duration.days(14),
            enforce_ssl=True,
        )

        # Primary SQS queue with DLQ redrive
        queue = sqs.Queue(
            self,
            "EventQueue",
            queue_name="event-processing-queue",
            encryption=sqs.QueueEncryption.KMS,
            encryption_master_key=encryption_key,
            data_key_reuse=Duration.minutes(5),
            visibility_timeout=Duration.seconds(180),
            retention_period=Duration.days(4),
            enforce_ssl=True,
            dead_letter_queue=sqs.DeadLetterQueue(
                max_receive_count=5,
                queue=dlq,
            ),
        )

        # DynamoDB table for event persistence
        table = dynamodb.Table(
            self,
            "EventsTable",
            table_name="events",
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
        )

        # Lambda execution role with least-privilege
        lambda_role = iam.Role(
            self,
            "EventProcessorRole",
            assumed_by=iam.ServicePrincipal("lambda.amazonaws.com"),
            description="Execution role for event processor Lambda",
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name(
                    "service-role/AWSLambdaBasicExecutionRole"
                ),
            ],
        )

        # Inline policy granting CloudWatch metrics publishing
        lambda_role.add_to_policy(
            iam.PolicyStatement(
                actions=["cloudwatch:PutMetricData"],
                resources=["*"],
                conditions={
                    "StringEquals": {
                        "cloudwatch:namespace": "EventDriven/Processor"
                    }
                },
            )
        )

        # Lambda function that processes SQS events
        processor_fn = _lambda.Function(
            self,
            "EventProcessor",
            function_name="event-processor",
            runtime=_lambda.Runtime.PYTHON_3_12,
            handler="handler.lambda_handler",
            code=_lambda.Code.from_inline(
                """
import json
import os
import time
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
cloudwatch = boto3.client("cloudwatch")
table = dynamodb.Table(os.environ["TABLE_NAME"])
METRIC_NAMESPACE = os.environ.get("METRIC_NAMESPACE", "EventDriven/Processor")


def lambda_handler(event, context):
    batch_item_failures = []
    processed = 0
    failed = 0

    for record in event.get("Records", []):
        message_id = record["messageId"]
        try:
            body = json.loads(record["body"])
            table.put_item(
                Item={
                    "pk": body.get("id", message_id),
                    "sk": body.get("type", "EVENT"),
                    "payload": body,
                    "received_at": int(time.time()),
                }
            )
            processed += 1
        except (ClientError, json.JSONDecodeError, KeyError) as e:
            print(f"Failed to process message {message_id}: {e}")
            batch_item_failures.append({"itemIdentifier": message_id})
            failed += 1

    try:
        cloudwatch.put_metric_data(
            Namespace=METRIC_NAMESPACE,
            MetricData=[
                {"MetricName": "MessagesProcessed", "Value": processed, "Unit": "Count"},
                {"MetricName": "MessagesFailed", "Value": failed, "Unit": "Count"},
            ],
        )
    except ClientError as e:
        print(f"Failed to publish metrics: {e}")

    return {"batchItemFailures": batch_item_failures}
"""
            ),
            role=lambda_role,
            timeout=Duration.seconds(60),
            memory_size=512,
            reserved_concurrent_executions=50,
            log_ret