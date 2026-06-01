from aws_cdk import (
    Stack,
    Duration,
    aws_lambda as _lambda,
    aws_sqs as sqs,
    aws_dynamodb as dynamodb,
    aws_lambda_event_sources as lambda_event_sources,
    aws_iam as iam,
)
from constructs import Construct

class EventDrivenStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # DynamoDB table with production defaults
        table = dynamodb.Table(
            self,
            "EventTable",
            partition_key=dynamodb.Attribute(name="id", type=dynamodb.AttributeType.STRING),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            encryption=dynamodb.TableEncryption.AWS_MANAGED,
            point_in_time_recovery=True,
            removal_policy=cdk.RemovalPolicy.RETAIN,
        )

        # Dead-letter queue
        dlq = sqs.Queue(
            self,
            "EventDLQ",
            encryption=sqs.QueueEncryption.KMS_MANAGED,
            retention_period=Duration.days(14),
        )

        # Main SQS queue
        queue = sqs.Queue(
            self,
            "EventQueue",
            visibility_timeout=Duration.seconds(300),
            encryption=sqs.QueueEncryption.KMS_MANAGED,
            dead_letter_queue=sqs.DeadLetterQueue(max_receive_count=3, queue=dlq),
        )

        # Lambda execution role with least-privilege permissions
        lambda_role = iam.Role(
            self,
            "EventLambdaRole",
            assumed_by=iam.ServicePrincipal("lambda.amazonaws.com"),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name("service-role/AWSLambdaBasicExecutionRole"),
            ],
        )

        lambda_role.add_to_policy(
            iam.PolicyStatement(
                actions=[
                    "dynamodb:PutItem",
                    "dynamodb:UpdateItem",
                ],
                resources=[table.table_arn],
            )
        )
        lambda_role.add_to_policy(
            iam.PolicyStatement(
                actions=["cloudwatch:PutMetricData"],
                resources=["*"],
            )
        )
        lambda_role.add_to_policy(
            iam.PolicyStatement(
                actions=[
                    "sqs:ReceiveMessage",
                    "sqs:DeleteMessage",
                    "sqs:GetQueueAttributes",
                ],
                resources=[queue.queue_arn],
            )
        )

        # Lambda function
        fn = _lambda.Function(
            self,
            "EventProcessor",
            runtime=_lambda.Runtime.PYTHON_3_11,
            handler="index.handler",
            code=_lambda.Code.from_inline(
                """
import json
import boto3
import os
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])
cloudwatch = boto3.client('cloudwatch')

def handler(event, context):
    for record in event['Records']:
        body = json.loads(record['body'])
        item_id = body.get('id', context.aws_request_id)
        table.put_item(Item={
            'id': item_id,
            'payload': body,
            'timestamp': datetime.utcnow().isoformat()
        })
        cloudwatch.put_metric_data(
            Namespace='EventDriven',
            MetricData=[{
                'MetricName': 'ItemsProcessed',
                'Value': 1,
                'Unit': 'Count'
            }]
        )
    return {'statusCode': 200}
"""
            ),
            role=lambda_role,
            timeout=Duration.seconds(60),
            memory_size=256,
            environment={"TABLE_NAME": table.table_name},
            tracing=_lambda.Tracing.ACTIVE,
        )

        # SQS event source
        fn.add_event_source(
            lambda_event_sources.SqsEventSource(
                queue,
                batch_size=10,
                max_batching_window=Duration.seconds(5),
            )
        )