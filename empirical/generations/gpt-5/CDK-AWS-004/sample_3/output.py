from aws_cdk import (
    App,
    Stack,
    Duration,
    RemovalPolicy,
    Tags,
    aws_sqs as sqs,
    aws_lambda as _lambda,
    aws_lambda_event_sources as lambda_event_sources,
    aws_iam as iam,
    aws_dynamodb as dynamodb,
    aws_logs as logs,
)
from constructs import Construct


class EventDrivenStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        metric_namespace = "EventPipeline/Processing"

        dlq = sqs.Queue(
            self,
            "ProcessingDLQ",
            encryption=sqs.QueueEncryption.SQS_MANAGED,
            retention_period=Duration.days(14),
        )

        queue = sqs.Queue(
            self,
            "ProcessingQueue",
            encryption=sqs.QueueEncryption.SQS_MANAGED,
            visibility_timeout=Duration.seconds(60),
            retention_period=Duration.days(4),
            dead_letter_queue=sqs.DeadLetterQueue(
                queue=dlq,
                max_receive_count=5,
            ),
        )

        table = dynamodb.Table(
            self,
            "RecordsTable",
            partition_key=dynamodb.Attribute(name="id", type=dynamodb.AttributeType.STRING),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            encryption=dynamodb.TableEncryption.AWS_MANAGED,
            point_in_time_recovery=True,
            removal_policy=RemovalPolicy.RETAIN,
        )

        lambda_fn = _lambda.Function(
            self,
            "QueueConsumerFunction",
            runtime=_lambda.Runtime.PYTHON_3_12,
            handler="index.handler",
            code=_lambda.Code.from_inline(
                """
import os
import json
import time
import uuid
import logging
import boto3
from botocore.config import Config

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

TABLE_NAME = os.environ["TABLE_NAME"]
METRIC_NAMESPACE = os.environ.get("METRIC_NAMESPACE", "App/Processing")

ddb = boto3.resource("dynamodb", config=Config(retries={"max_attempts": 5, "mode": "standard"}))
cw = boto3.client("cloudwatch", config=Config(retries={"max_attempts": 5, "mode": "standard"}))
table = ddb.Table(TABLE_NAME)

def handler(event, context):
    failed_ids = []
    processed = 0

    for record in event.get("Records", []):
        msg_id = record.get("messageId")
        body = record.get("body", "")
        try:
            payload = None
            try:
                payload = json.loads(body)
            except Exception:
                payload = {"raw": body}

            item = {
                "id": str(uuid.uuid4()),
                "timestamp": int(time.time()),
                "payload": payload,
            }

            table.put_item(
                Item=item,
                ConditionExpression="attribute_not_exists(id)"
            )
            processed += 1
        except Exception as e:
            logger.exception("Failed processing messageId=%s: %s", msg_id, str(e))
            if msg_id:
                failed_ids.append(msg_id)

    # Emit CloudWatch custom metrics
    try:
        metric_data = []
        metric_data.append({
            "MetricName": "ProcessedMessages",
            "Dimensions": [{"Name": "FunctionName", "Value": context.function_name}],
            "Timestamp": time.time(),
            "Unit": "Count",
            "Value": processed,
        })
        metric_data.append({
            "MetricName": "FailedMessages",
            "Dimensions": [{"Name": "FunctionName", "Value": context.function_name}],
            "Timestamp": time.time(),
            "Unit": "Count",
            "Value": len(failed_ids),
        })
        if metric_data:
            cw.put_metric_data(Namespace=METRIC_NAMESPACE, MetricData=metric_data)
    except Exception:
        logger.exception("Failed to emit CloudWatch metrics")

    # Report partial failures for SQS batch
    return {"batchItemFailures": [{"itemIdentifier": mid} for mid in failed_ids]}
                """
            ),
            memory_size=256,
            timeout=Duration.seconds(30),
            architecture=_lambda.Architecture.ARM_64,
            tracing=_lambda.Tracing.ACTIVE,
            log_retention=logs.RetentionDays.THREE_MONTHS,
            environment={
                "TABLE_NAME": table.table_name,
                "METRIC_NAMESPACE": metric_namespace,
            },
            reserved_concurrent_executions=10,
        )

        table.grant_write_data(lambda_fn)

        lambda_fn.add_to_role_policy(
            iam.PolicyStatement(
                actions=["cloudwatch:PutMetricData"],
                resources=["*"],
                conditions={"StringEquals": {"cloudwatch:namespace": metric_namespace}},
            )
        )

        lambda_fn.add_event_source(
            lambda_event_sources.SqsEventSource(
                queue,
                batch_size=10,
                max_batching_window=Duration.seconds(5),
                report_batch_item_failures=True,
            )
        )

        Tags.of(self).add("Project", "EventDriven")
        Tags.of(self).add("Service", "SqsLambdaDdbPipeline")


app = App()
EventDrivenStack(app, "EventDrivenStack")
app.synth()