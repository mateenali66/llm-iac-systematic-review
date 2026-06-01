from aws_cdk import (
    Stack,
    App,
    Duration,
    RemovalPolicy,
    aws_sqs as sqs,
    aws_lambda as _lambda,
    aws_lambda_event_sources as event_sources,
    aws_dynamodb as dynamodb,
    aws_iam as iam,
    aws_logs as logs,
)
from constructs import Construct

class EventDrivenStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        dlq = sqs.Queue(
            self,
            "EventDlq",
            encryption=sqs.QueueEncryption.KMS_MANAGED,
            enforce_ssl=True,
            retention_period=Duration.days(14),
        )

        queue = sqs.Queue(
            self,
            "EventQueue",
            encryption=sqs.QueueEncryption.KMS_MANAGED,
            enforce_ssl=True,
            visibility_timeout=Duration.seconds(90),
            dead_letter_queue=sqs.DeadLetterQueue(queue=dlq, max_receive_count=5),
        )

        table = dynamodb.Table(
            self,
            "ItemsTable",
            partition_key=dynamodb.Attribute(name="id", type=dynamodb.AttributeType.STRING),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            encryption=dynamodb.TableEncryption.AWS_MANAGED,
            removal_policy=RemovalPolicy.RETAIN,
        )

        lambda_fn = _lambda.Function(
            self,
            "QueueProcessorFn",
            runtime=_lambda.Runtime.PYTHON_3_12,
            architecture=_lambda.Architecture.ARM_64,
            handler="index.handler",
            code=_lambda.Code.from_inline(
                """
import os
import json
import time
import uuid
from datetime import datetime, timezone
import boto3
from botocore.config import Config

TABLE_NAME = os.environ.get("TABLE_NAME")
METRIC_NAMESPACE = os.environ.get("METRIC_NAMESPACE", "App/EventProcessing")

boto_config = Config(retries={"max_attempts": 4, "mode": "standard"})
dynamodb = boto3.resource("dynamodb", config=boto_config)
table = dynamodb.Table(TABLE_NAME)
cloudwatch = boto3.client("cloudwatch", config=boto_config)

def _put_metric(namespace, name, value, unit="Count", dimensions=None, storage_resolution=60):
    try:
        cloudwatch.put_metric_data(
            Namespace=namespace,
            MetricData=[
                {
                    "MetricName": name,
                    "Dimensions": dimensions or [],
                    "Timestamp": datetime.now(timezone.utc),
                    "Unit": unit,
                    "Value": float(value),
                    "StorageResolution": storage_resolution,
                }
            ],
        )
    except Exception as e:
        # Avoid raising metric emission failures
        print(f"Metric emission failed: {e}")

def handler(event, context):
    start_ts = time.time()
    failures = []
    processed = 0

    for record in event.get("Records", []):
        msg_id = record.get("messageId")
        try:
            body = record.get("body", "")
            try:
                payload = json.loads(body) if body else {}
            except Exception:
                payload = {"raw": body}

            item_id = str(payload.get("id") or uuid.uuid4())
            item = {
                "id": item_id,
                "payload": payload,
                "receivedAt": int(time.time() * 1000),
            }

            table.put_item(Item=item)
            processed += 1
        except Exception as e:
            print(f"Failed to process message {msg_id}: {e}")
            if msg_id:
                failures.append({"itemIdentifier": msg_id})

    elapsed_ms = int((time.time() - start_ts) * 1000)

    dims = [{"Name": "FunctionName", "Value": context.function_name}]
    _put_metric(METRIC_NAMESPACE, "ItemsProcessed", processed, "Count", dims)
    _put_metric(METRIC_NAMESPACE, "BatchFailures", len(failures), "Count", dims)
    _put_metric(METRIC_NAMESPACE, "BatchProcessingTime", elapsed_ms, "Milliseconds", dims)

    return {"batchItemFailures": failures}
                """
            ),
            timeout=Duration.seconds(30),
            memory_size=512,
            reserved_concurrent_executions=10,
            log_retention=logs.RetentionDays.THREE_MONTHS,
            tracing=_lambda.Tracing.ACTIVE,
            environment={
                "TABLE_NAME": table.table_name,
                "METRIC_NAMESPACE": "MyApp/EventProcessing",
            },
        )

        table.grant_write_data(lambda_fn)

        lambda_fn.add_to_role_policy(
            iam.PolicyStatement(
                actions=["cloudwatch:PutMetricData"],
                resources=["*"],
                conditions={"StringEquals": {"cloudwatch:namespace": "MyApp/EventProcessing"}},
            )
        )

        lambda_fn.add_event_source(
            event_sources.SqsEventSource(
                queue,
                batch_size=10,
                max_batching_window=Duration.seconds(5),
                report_batch_item_failures=True,
                enabled=True,
            )
        )

app = App()
EventDrivenStack(app, "EventDrivenStack")
app.synth()