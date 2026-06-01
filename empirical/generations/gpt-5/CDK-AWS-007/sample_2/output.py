from aws_cdk import (
    Stack,
    RemovalPolicy,
    Aws,
)
from aws_cdk import aws_dynamodb as dynamodb
from constructs import Construct

class DynamoDbStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, *, table_name: str = None, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        table = dynamodb.Table(
            self,
            "AppTable",
            table_name=table_name or f"{Aws.STACK_NAME}-data",
            partition_key=dynamodb.Attribute(name="pk", type=dynamodb.AttributeType.STRING),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            encryption=dynamodb.TableEncryption.AWS_MANAGED,
            contributor_insights_enabled=True,
            removal_policy=RemovalPolicy.RETAIN,
        )

        table.add_global_secondary_index(
            index_name="customer-id-index",
            partition_key=dynamodb.Attribute(name="customer_id", type=dynamodb.AttributeType.STRING),
            projection_type=dynamodb.ProjectionType.ALL,
        )