from aws_cdk import (
    Stack,
    Duration,
    aws_sqs as sqs,
    aws_lambda as _lambda,
    aws_dynamodb as ddb,
    aws_lambda_event_sources as sources,
    aws_iam as iam,
)
from constructs import Construct

class EventDrivenStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        table = ddb.Table(
            self, "EventsTable",
            partition_key=ddb.Attribute(name="pk", type=ddb.AttributeType.STRING),
            sort_key=ddb.Attribute(name="sk", type=ddb.AttributeType.STRING),
            billing_mode=ddb.BillingMode.PAY_PER_REQUEST,
            encryption=ddb.TableEncryption.AWS_MANAGED,
            point_in_time_recovery=True,
        )

        dlq = sqs.Queue(
            self, "EventsDLQ",
            encryption=sqs.QueueEncryption.SQS_MANAGED,
            retention_period=Duration.days(14),
        )

        queue = sqs.Queue(
            self, "EventsQueue",
            encryption=sqs.QueueEncryption.SQS_MANAGED,
            dead_letter_queue=sqs.DeadLetterQueue(max_receive_count=3, queue=dlq),
            visibility_timeout=Duration.seconds(300),
        )

        fn = _lambda.Function(
            self, "EventProcessor",
            runtime=_lambda.Runtime.PYTHON_3_11,
            handler="index.handler",
            code=_lambda.Code.from_inline(
                """import json, os, boto3
from datetime import datetime, timezone
ddb = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
cw = boto3.client("cloudwatch")

def handler(event, context):
    for rec in event.get("Records", []):
        body = json.loads(rec["body"])
        ddb.put_item(Item={"pk": body.get("id", "default"), "sk": datetime.now(timezone.utc).isoformat(), "payload": body})
        cw.put_metric_data(Namespace="EventProcessing", MetricData=[{"MetricName": "MessagesProcessed", "Value": 1, "Unit": "Count"}])
    return {"statusCode": 200}
"""
            ),
            environment={"TABLE_NAME": table.table_name},
            timeout=Duration.seconds(30),
            memory_size=512,
        )

        table.grant_write_data(fn)
        fn.add_to_role_policy(
            iam.PolicyStatement(
                actions=["cloudwatch:PutMetricData"],
                resources=["*"],
            )
        )

        fn.add_event_source(sources.SqsEventSource(queue, batch_size=10))