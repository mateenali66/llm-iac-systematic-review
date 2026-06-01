from aws_cdk import (
    Stack,
    aws_sqs as sqs,
    aws_lambda as lambda_,
    aws_lambda_event_sources as lambda_event_sources,
    aws_dynamodb as dynamodb,
    aws_cloudwatch as cloudwatch,
    aws_iam as iam,
    Duration,
    RemovalPolicy,
)
from constructs import Construct


class EventDrivenStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # SQS Queue with dead-letter queue
        dlq = sqs.Queue(
            self, "DeadLetterQueue",
            retention_period=Duration.days(14),
            removal_policy=RemovalPolicy.DESTROY,
        )

        queue = sqs.Queue(
            self, "EventQueue",
            visibility_timeout=Duration.seconds(300),
            retention_period=Duration.days(4),
            dead_letter_queue=sqs.DeadLetterQueue(
                max_receive_count=3,
                queue=dlq,
            ),
            removal_policy=RemovalPolicy.DESTROY,
        )

        # DynamoDB table
        table = dynamodb.Table(
            self, "EventTable",
            partition_key=dynamodb.Attribute(
                name="id",
                type=dynamodb.AttributeType.STRING,
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            removal_policy=RemovalPolicy.DESTROY,
            point_in_time_recovery=True,
        )

        # Lambda function
        lambda_role = iam.Role(
            self, "LambdaExecutionRole",
            assumed_by=iam.ServicePrincipal("lambda.amazonaws.com"),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name(
                    "service-role/AWSLambdaBasicExecutionRole"
                ),
            ],
        )

        table.grant_write_data(lambda_role)
        queue.grant_consume_messages(lambda_role)

        lambda_fn = lambda_.Function(
            self, "EventHandler",
            runtime=lambda_.Runtime.PYTHON_3_12,
            handler="index.handler",
            code=lambda_.Code.from_inline(
                """
import json
import os
import uuid
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table_name = os.environ['TABLE_NAME']
cloudwatch = boto3.client('cloudwatch')

def handler(event, context):
    table = dynamodb.Table(table_name)
    for record in event['Records']:
        body = json.loads(record['body'])
        item = {
            'id': str(uuid.uuid4()),
            'timestamp': datetime.utcnow().isoformat(),
            'data': body,
        }
        table.put_item(Item=item)

        cloudwatch.put_metric_data(
            Namespace='EventDrivenApp',
            MetricData=[
                {
                    'MetricName': 'ProcessedEvents',
                    'Value': 1,
                    'Unit': 'Count',
                },
                {
                    'MetricName': 'EventProcessingTime',
                    'Value': 0.1,
                    'Unit': 'Seconds',
                },
            ]
        )
    return {'statusCode': 200}
"""
            ),
            environment={
                "TABLE_NAME": table.table_name,
            },
            role=lambda_role,
            timeout=Duration.seconds(60),
            memory_size=128,
        )

        # SQS event source for Lambda
        lambda_fn.add_event_source(
            lambda_event_sources.SqsEventSource(
                queue,
                batch_size=10,
                max_batching_window=Duration.seconds(5),
            )
        )

        # CloudWatch metric for queue depth
        cloudwatch.Metric(
            self, "QueueDepthMetric",
            namespace="AWS/SQS",
            metric_name="ApproximateNumberOfMessagesVisible",
            dimensions_map={"QueueName": queue.queue_name},
        )