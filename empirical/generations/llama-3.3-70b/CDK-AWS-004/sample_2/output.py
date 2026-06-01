import aws_cdk as cdk
from aws_cdk import (
    aws_lambda as _lambda,
    aws_sqs as sqs,
    aws_dynamodb as dynamodb,
    aws_iam as iam,
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
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            partition_key=dynamodb.Attribute(
                name="id",
                type=dynamodb.AttributeType.STRING,
            ),
        )

        # Create a Lambda function
        lambda_function = _lambda.Function(
            self, "EventProcessor",
            runtime=_lambda.Runtime.PYTHON_3_9,
            handler="index.handler",
            code=_lambda.Code.from_asset("lambda"),
            environment={
                "TABLE_NAME": table.table_name,
            },
        )

        # Grant the Lambda function execution role permissions to read from the SQS queue
        queue.grant_consume_messages(lambda_function)

        # Grant the Lambda function execution role permissions to write to the DynamoDB table
        table.grant_write_data(lambda_function)

        # Create a CloudWatch metric
        metric = cloudwatch.Metric(
            namespace="EventDrivenArchitecture",
            metric_name="EventsProcessed",
            unit=cloudwatch.Unit.COUNT,
        )

        # Create a CloudWatch dashboard
        dashboard = cloudwatch.Dashboard(
            self, "EventDashboard",
            dashboard_name="EventDrivenArchitecture",
        )

        # Add a widget to the dashboard to display the metric
        dashboard.add_widgets(
            cloudwatch.SingleValueWidget(
                title="Events Processed",
                metrics=[metric],
            ),
        )

        # Create a Lambda event source mapping to trigger the Lambda function from the SQS queue
        _lambda.EventSourceMapping(
            self, "EventSourceMapping",
            event_source_arn=queue.queue_arn,
            target=lambda_function,
        )