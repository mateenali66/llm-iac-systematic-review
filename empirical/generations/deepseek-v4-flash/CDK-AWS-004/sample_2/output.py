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

        # SQS Queue - dead-letter queue for resilience
        dead_letter_queue = sqs.Queue(
            self, "DeadLetterQueue",
            retention_period=Duration.days(14),
            encryption=sqs.QueueEncryption.SQS_MANAGED,
            enforce_ssl=True,
        )

        queue = sqs.Queue(
            self, "EventQueue",
            visibility_timeout=Duration.seconds(300),
            retention_period=Duration.days(4),
            encryption=sqs.QueueEncryption.SQS_MANAGED,
            enforce_ssl=True,
            dead_letter_queue=sqs.DeadLetterQueue(
                max_receive_count=3,
                queue=dead_letter_queue,
            ),
        )

        # DynamoDB table
        table = dynamodb.Table(
            self, "EventTable",
            partition_key=dynamodb.Attribute(
                name="id",
                type=dynamodb.AttributeType.STRING,
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            encryption=dynamodb.TableEncryption.AWS_MANAGED,
            removal_policy=RemovalPolicy.RETAIN,
            point_in_time_recovery=True,
        )

        # Lambda function
        lambda_function = lambda_.Function(
            self, "EventHandler",
            runtime=lambda_.Runtime.PYTHON_3_12,
            handler="index.handler",
            code=lambda_.Code.from_asset("lambda"),
            timeout=Duration.seconds(60),
            memory_size=256,
            environment={
                "TABLE_NAME": table.table_name,
            },
            tracing=lambda_.Tracing.ACTIVE,
        )

        # Grant Lambda permissions to write to DynamoDB and publish metrics
        table.grant_write_data(lambda_function)
        lambda_function.add_to_role_policy(
            iam.PolicyStatement(
                actions=["cloudwatch:PutMetricData"],
                resources=["*"],
                conditions={
                    "StringEquals": {
                        "cloudwatch:namespace": "EventDrivenApp"
                    }
                },
            )
        )

        # SQS event source for Lambda
        lambda_function.add_event_source(
            lambda_event_sources.SqsEventSource(
                queue,
                batch_size=10,
                max_batching_window=Duration.seconds(5),
                report_batch_item_failures=True,
            )
        )

        # CloudWatch metric for processed messages
        cloudwatch.Metric(
            namespace="EventDrivenApp",
            metric_name="MessagesProcessed",
            statistic="Sum",
            unit=cloudwatch.Unit.COUNT,
        )

        # Outputs
        self.queue_url = queue.queue_url
        self.table_name = table.table_name
        self.function_name = lambda_function.function_name