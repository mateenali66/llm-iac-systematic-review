from aws_cdk import (
    Duration,
    Stack,
    aws_dynamodb as ddb,
    aws_iam as iam,
    aws_lambda as _lambda,
    aws_lambda_event_sources as events,
    aws_sqs as sqs,
)
from constructs import Construct


class EventDrivenStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        table = ddb.Table(
            self,
            "EventsTable",
            partition_key=ddb.Attribute(name="pk", type=ddb.AttributeType.STRING),
            sort_key=ddb.Attribute(name="sk", type=ddb.AttributeType.STRING),
            billing_mode=ddb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            encryption=ddb.TableEncryption.AWS_MANAGED,
        )

        queue = sqs.Queue(
            self,
            "EventQueue",
            visibility_timeout=Duration.seconds(300),
            encryption=sqs.QueueEncryption.SQS_MANAGED,
            dead_letter_queue=sqs.DeadLetterQueue(
                max_receive_count=3,
                queue=sqs.Queue(
                    self,
                    "EventDLQ",
                    encryption=sqs.QueueEncryption.SQS_MANAGED,
                ),
            ),
        )

        fn = _lambda.Function(
            self,
            "EventProcessor",
            runtime=_lambda.Runtime.PYTHON_3_11,
            handler="index.handler",
            code=_lambda.Code.from_inline(
                "import json, os, boto3\n"
                "dynamodb = boto3.resource('dynamodb')\n"
                "table = dynamodb.Table(os.environ['TABLE_NAME'])\n"
                "cw = boto3.client('cloudwatch')\n"
                "def handler(event, context):\n"
                "    for record in event.get('Records', []):\n"
                "        body = json.loads(record['body'])\n"
                "        table.put_item(Item={'pk': record['messageId'], 'sk': 'event', **body})\n"
                "        cw.put_metric_data(Namespace='EventDriven', MetricData=[{'MetricName': 'MessagesProcessed', 'Value': 1}])\n"
                "    return {'statusCode': 200}"
            ),
            environment={"TABLE_NAME": table.table_name},
            timeout=Duration.seconds(30),
            memory_size=256,
            tracing=_lambda.Tracing.ACTIVE,
        )

        table.grant_write_data(fn)
        queue.grant_consume_messages(fn)
        fn.add_to_role_policy(
            iam.PolicyStatement(
                actions=["cloudwatch:PutMetricData"],
                resources=["*"],
            )
        )

        fn.add_event_source(events.SqsEventSource(queue, batch_size=10))