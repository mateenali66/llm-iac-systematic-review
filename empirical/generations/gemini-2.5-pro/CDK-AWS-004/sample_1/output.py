from constructs import Construct
import aws_cdk as cdk
from aws_cdk import (
    Duration,
    RemovalPolicy,
    aws_dynamodb as dynamodb,
    aws_iam as iam,
    aws_lambda as _lambda,
    aws_lambda_event_sources as lambda_event_sources,
    aws_sqs as sqs,
    aws_logs as logs
)

class EventDrivenArchStack(cdk.Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # DynamoDB Table for storing processed data
        # Best practice: Retain table on stack deletion, enable PITR for production
        processed_items_table = dynamodb.Table(
            self, "ProcessedItemsTable",
            partition_key=dynamodb.Attribute(
                name="id",
                type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            encryption=dynamodb.TableEncryption.AWS_MANAGED,
            point_in_time_recovery=True,
            removal_policy=RemovalPolicy.RETAIN
        )

        # SQS Dead-Letter Queue for handling message processing failures
        # Best practice: Always have a DLQ for asynchronous processing
        dlq = sqs.Queue(
            self, "ProcessingDLQ",
            retention_period=Duration.days(14),
            encryption=sqs.QueueEncryption.SQS_MANAGED
        )

        # Main SQS Queue that triggers the Lambda function
        # Best practice: Set visibility timeout > Lambda timeout
        queue = sqs.Queue(
            self, "ProcessingQueue",
            visibility_timeout=Duration.seconds(180),
            encryption=sqs.QueueEncryption.SQS_MANAGED,
            dead_letter_queue=sqs.DeadLetterQueue(
                max_receive_count=5,
                queue=dlq
            )
        )

        # Lambda Function to process messages from the SQS queue
        # Best practice: Use specific IAM permissions, set memory/timeout, and enable tracing
        processor_lambda = _lambda.Function(
            self, "QueueProcessorLambda",
            runtime=_lambda.Runtime.PYTHON_3_11,
            handler="index.handler",
            code=_lambda.Code.from_inline(
                """
import