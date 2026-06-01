from aws_cdk import (
    App,
    Stack,
    Duration,
    RemovalPolicy,
    aws_lambda as _lambda,
    aws_dynamodb as dynamodb,
    aws_sqs as sqs,
    aws_lambda_event_sources as event_sources,
    aws_iam as iam,
    aws_logs as logs,
)
from constructs import Construct


class EventDrivenStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        metric_namespace = "EventApp"

        dlq = sqs.Queue(
            self,
            "DeadLetterQueue",
            encryption=sqs.QueueEncryption.SQS_MANAGED,
            enforce_ssl=True,
            retention_period=Duration.days(14),
            visibility_timeout=Duration.seconds(120),
        )
        dlq.apply_removal_policy(RemovalPolicy.RETAIN)
        dlq.add_to_resource_policy(
            iam.PolicyStatement(
                sid="DenyInsecureTransport",
                effect=iam.Effect.DENY,
                principals=[iam.AnyPrincipal()],
                actions=["sqs:*"],
                resources=[dlq.queue_arn],
                conditions={"Bool": {"aws:SecureTransport": "false"}},
            )
        )

        queue = sqs.Queue(
            self,
            "MainQueue",
            encryption=sqs.QueueEncryption.SQS_MANAGED,
            enforce_ssl=True,
            visibility_timeout=Duration.seconds(120),
            dead_letter_queue=sqs.DeadLetterQueue(queue=dlq, max_receive_count=5),
        )
        queue.apply_removal_policy(RemovalPolicy.RETAIN)
        queue.add_to_resource_policy(
            iam.PolicyStatement(
                sid="DenyInsecureTransport",
                effect=iam.Effect.DENY,
                principals=[iam.AnyPrincipal()],
                actions=["sqs:*"],
                resources=[queue.queue_arn],
                conditions={"Bool": {"aws:SecureTransport": "false"}},
            )
        )

        table = dynamodb.Table(
            self,
            "MessagesTable",
            partition_key=dynamodb.Attribute(name="id", type=dynamodb.AttributeType.STRING),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            encryption=dynamodb.TableEncryption.AWS_MANAGED,
        )
        table.apply_removal_policy(RemovalPolicy.RETAIN)

        lambda_code = _lambda.Code.from_inline(
            """
import os
import json
import time
import logging
from decimal import Decimal
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ddb = boto3.resource('dynamodb')
cw = boto3.client('cloudwatch')

TABLE_NAME = os.environ.get('TABLE_NAME')
METRIC_NAMESPACE = os.environ.get('METRIC_NAMESPACE', 'EventApp')
table = ddb.Table(TABLE_NAME)

def _to_ddb_compatible(obj):
    if isinstance(obj, float):
        return Decimal(str(obj))
    if isinstance(obj, list):
        return [_to_ddb_compatible(i) for i in obj]
    if isinstance(obj, dict):
        return {k: _to_ddb_compatible(v) for k, v in obj.items()}
    return obj

def lambda_handler(event, context):
    start = time.time()
    records = event.get('Records', [])
    failures = []
    processed = 0

    for r in records:
        message_id = r.get('messageId')
        body = r.get('body')
        try:
            payload = json.loads(body, parse_float=Decimal) if body else {}
        except Exception:
            payload = {'raw': body}

        item = {
            'id': message_id,
            'receivedAt': int(time.time()),
            'payload': _to_ddb_compatible(payload)
        }

        try:
            table.put_item(
                Item=item,
                ConditionExpression='attribute_not_exists(#id)',
                ExpressionAttributeNames={'#id': 'id'}
            )
            processed += 1
        except ClientError as e:
            if e.response.get('Error', {}).get('Code') == 'ConditionalCheckFailedException':
                # Duplicate message id; treat as success (idempotent)
                logger.info('Duplicate id %s, treating as success', message_id)
                processed += 1
            else:
                logger.exception('Failed to process message_id=%s', message_id)
                failures.append({'itemIdentifier': message_id})

    duration_ms = int((time.time() - start) * 1000)

    try:
        cw.put_metric_data(
            Namespace=METRIC_NAMESPACE,
            MetricData=[
                {
                    'MetricName': 'ProcessedMessages',
                    'Dimensions': [{'Name': 'FunctionName', 'Value': context.function_name}],
                    'Unit': 'Count',
                    'Value': processed
                },
                {
                    'MetricName': 'FailedMessages',
                    'Dimensions': [{'Name': 'FunctionName', 'Value': context.function_name}],
                    'Unit': 'Count',
                    'Value': len(failures)
                },
                {
                    'MetricName': 'DurationMs',
                    'Dimensions': [{'Name': 'FunctionName', 'Value': context.function_name}],
                    'Unit': 'Milliseconds',
                    'Value': duration_ms
                }
            ]
        )
    except Exception:
        logger.exception('Failed to publish CloudWatch metrics')

    return {'batchItemFailures': failures}
"""
        )

        fn = _lambda.Function(
            self,
            "QueueConsumerFn",
            runtime=_lambda.Runtime.PYTHON_3_12,
            handler="index.lambda_handler",
            code=lambda_code,
            architecture=_lambda.Architecture.ARM_64,
            memory_size=512,
            timeout=Duration.seconds(30),
            reserved_concurrent_executions=10,
            environment={
                "TABLE_NAME": table.table_name,
                "METRIC_NAMESPACE": metric_namespace,
            },
            log_retention=logs.RetentionDays.THREE_MONTHS,
            tracing=_lambda.Tracing.ACTIVE,
            description="Consumes SQS messages, writes to DynamoDB, and emits CloudWatch metrics",
        )

        table.grant_write_data(fn)

        fn.add_to_role_policy(
            iam.PolicyStatement(
                actions=["cloudwatch:PutMetricData"],
                resources=["*"],
                conditions={"StringEquals": {"cloudwatch:namespace": metric_namespace}},
            )
        )

        fn.add_event_source(
            event_sources.SqsEventSource(
                queue,
                batch_size=10,
                max_batching_window=Duration.seconds(5),
                report_batch_item_failures=True,
                max_concurrency=5,
                enabled=True,
            )
        )


app = App()
EventDrivenStack(app, "EventDrivenStack")
app.synth()