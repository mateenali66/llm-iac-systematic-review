from aws_cdk import (
    Stack,
    aws_lambda as _lambda,
    aws_sqs as sqs,
    aws_dynamodb as dynamodb,
    aws_iam as iam,
    aws_cloudwatch as cloudwatch,
    Duration,
    CfnOutput
)
from constructs import Construct

class EventDrivenArchitectureStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create SQS Queue
        queue = sqs.Queue(
            self, "ProcessingQueue",
            visibility_timeout=Duration.seconds(300),
            encryption=sqs.QueueEncryption.SQS_MANAGED
        )

        # Create DynamoDB Table
        table = dynamodb.Table(
            self, "ProcessingTable",
            partition_key=dynamodb.Attribute(
                name="id",
                type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            encryption=dynamodb.TableEncryption.AWS_MANAGED,
            point_in_time_recovery=True
        )

        # Create Lambda Function
        handler = _lambda.Function(
            self, "ProcessorFunction",
            runtime=_lambda.Runtime.PYTHON_3_9,
            code=_lambda.Code.from_inline("""
import json
import boto3
import os
import uuid
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])
cloudwatch = boto3.client('cloudwatch')

def lambda_handler(event, context):
    processed_count = 0
    failed_count = 0
    
    for record in event['Records']:
        try:
            message_body = record['body']
            message_data = json.loads(message_body)
            
            # Process and store in DynamoDB
            table.put_item(
                Item={
                    'id': str(uuid.uuid4()),
                    'data': message_data,
                    'processed_at': datetime.utcnow().isoformat(),
                    'message_id': record['messageId']
                }
            )
            processed_count += 1
        except Exception as e:
            print(f"Error processing message: {e}")
            failed_count += 1
    
    # Emit CloudWatch metrics
    cloudwatch.put_metric_data(
        Namespace='Custom/EventProcessing',
        MetricData=[
            {
                'MetricName': 'MessagesProcessed',
                'Value': processed_count,
                'Unit': 'Count',
                'Dimensions': [
                    {'Name': 'FunctionName', 'Value': context.function_name}
                ]
            },
            {
                'MetricName': 'MessagesFailed',
                'Value': failed_count,
                'Unit': 'Count',
                'Dimensions': [
                    {'Name': 'FunctionName', 'Value': context.function_name}
                ]
            }
        ]
    )
    
    return {
        'statusCode': 200,
        'processed': processed_count,
        'failed': failed_count
    }
"""),
            handler="index.lambda_handler",
            environment={
                "TABLE_NAME": table.table_name
            },
            timeout=Duration.seconds(60)
        )

        # Grant Lambda permissions
        table.grant_write_data(handler)
        queue.grant_consume_messages(handler)

        # Add CloudWatch permissions
        handler.add_to_role_policy(
            iam.PolicyStatement(
                actions=[
                    "cloudwatch:PutMetricData"
                ],
                resources=["*"]
            )
        )

        # Create Event Source Mapping
        handler.add_event_source_mapping(
            "SQSEventSource",
            event_source_arn=queue.queue_arn,
            batch_size=10,
            max_batching_window=Duration.seconds(5)
        )

        # Create CloudWatch Dashboard
        dashboard = cloudwatch.Dashboard(
            self, "ProcessingDashboard",
            dashboard_name="EventProcessingDashboard"
        )

        # Add widgets to dashboard
        dashboard.add_widgets(
            cloudwatch.GraphWidget(
                title="Messages Processed",
                left=[
                    cloudwatch.Metric(
                        namespace="Custom/EventProcessing",
                        metric_name="MessagesProcessed",
                        statistic="Sum",
                        period=Duration.minutes(1)
                    )
                ]
            ),
            cloudwatch.GraphWidget(
                title="Messages Failed",
                left=[
                    cloudwatch.Metric(
                        namespace="Custom/EventProcessing",
                        metric_name="MessagesFailed",
                        statistic="Sum",
                        period=Duration.minutes(1)
                    )
                ]
            )
        )

        # Outputs
        CfnOutput(
            self, "QueueUrl",
            value=queue.queue_url,
            export_name="ProcessingQueueUrl"
        )
        
        CfnOutput(
            self, "TableName",
            value=table.table_name,
            export_name="ProcessingTableName"
        )