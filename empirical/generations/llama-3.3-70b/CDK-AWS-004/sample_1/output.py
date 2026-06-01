import aws_cdk as cdk
from aws_cdk import (
    aws_lambda as _lambda,
    aws_iam as iam,
    aws_sqs as sqs,
    aws_dynamodb as dynamodb,
    aws_cloudwatch as cloudwatch,
)

class EventDrivenArchitectureStack(cdk.Stack):
    def __init__(self, scope: cdk.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Create an SQS queue
        queue = sqs.Queue(
            self, "EventQueue",
            visibility_timeout=cdk.Duration.seconds(300),
            receive_message_wait_time=cdk.Duration.seconds(20),
        )

        # Create a DynamoDB table
        table = dynamodb.Table(
            self, "EventTable",
            table_name="events",
            attribute_definitions=[
                dynamodb.Attribute(
                    name="id",
                    type=dynamodb.AttributeType.STRING,
                ),
            ],
            key_schema=[
                dynamodb.KeySchema(
                    attribute_name="id",
                    key_type=dynamodb.KeyType.HASH,
                ),
            ],
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
        )

        # Create a Lambda function
        lambda_function = _lambda.Function(
            self, "EventProcessor",
            runtime=_lambda.Runtime.PYTHON_3_9,
            handler="index.handler",
            code=_lambda.Code.from_asset("lambda"),
            environment={
                "TABLE_NAME": table.table_name,
                "QUEUE_URL": queue.queue_url,
            },
        )

        # Grant the Lambda function execution role permissions to read from the SQS queue and write to the DynamoDB table
        queue.grant_consume_messages(lambda_function)
        table.grant_write_data(lambda_function)

        # Create a CloudWatch metric
        metric = cloudwatch.Metric(
            namespace="EventDrivenArchitecture",
            metric_name="EventsProcessed",
            unit=cloudwatch.Unit.COUNT,
        )

        # Create a Lambda function metric
        lambda_function.metric_invocations(
            namespace="AWS/Lambda",
            metric_name="Invocations",
            unit=cloudwatch.Unit.COUNT,
        )

        # Create an event source mapping for the Lambda function
        event_source_mapping = _lambda.EventSourceMapping(
            self, "EventSourceMapping",
            event_source_arn=queue.queue_arn,
            target=lambda_function,
        )

        # Create a CloudWatch log group for the Lambda function
        log_group = _lambda.LogGroup(
            self, "LogGroup",
            log_group_name=f"/aws/lambda/{lambda_function.function_name}",
            retention=cdk.Duration.days(30),
        )