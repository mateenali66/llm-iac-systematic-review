from aws_cdk import (
    Stack,
    aws_lambda as _lambda,
    aws_sqs as sqs,
    aws_dynamodb as dynamodb,
    aws_iam as iam,
    aws_lambda_event_sources as lambda_event_sources,
    Duration,
    CfnOutput
)
from constructs import Construct

class EventDrivenStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create DynamoDB table
        table = dynamodb.Table(
            self, "ProcessingTable",
            partition_key=dynamodb.Attribute(
                name="id",
                type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            encryption=dynamodb.TableEncryption.AWS_MANAGED
        )

        # Create SQS queue
        queue = sqs.Queue(
            self, "ProcessingQueue",
            visibility_timeout=Duration.seconds(300),
            encryption=sqs.QueueEncryption.SQS_MANAGED
        )

        # Create Lambda function
        handler = _lambda.Function(
            self, "ProcessingHandler",
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

def handler(event, context):
    for record in event['Records']:
        # Process message
        message_body = record['body']
        
        # Write to DynamoDB
        item = {
            'id': str(uuid.uuid4()),
            'message': message_body,
            'processed_at': datetime.utcnow().isoformat()
        }
        table.put_item(Item=item)
        
        # Emit CloudWatch metric
        cloudwatch.put_metric_data(
            Namespace='Custom/EventProcessing',
            MetricData=[
                {
                    'MetricName': 'MessagesProcessed',
                    'Value': 1,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'FunctionName',
                            'Value': context.function_name
                        }
                    ]
                }
            ]
        )
    
    return {'statusCode': 200, 'body': 'Processed successfully'}
"""),
            handler="index.handler",
            environment={
                "TABLE_NAME": table.table_name
            },
            timeout=Duration.seconds(60)
        )

        # Grant Lambda permissions
        table.grant_write_data(handler)
        queue.grant_consume_messages(handler)
        
        # Add SQS as event source for Lambda
        handler.add_event_source(
            lambda_event_sources.SqsEventSource(queue, batch_size=10)
        )

        # Output queue URL
        CfnOutput(
            self, "QueueUrl",
            value=queue.queue_url,
            description="URL of the SQS queue"
        )