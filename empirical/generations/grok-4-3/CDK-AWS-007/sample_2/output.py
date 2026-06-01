from aws_cdk import Stack, RemovalPolicy
from aws_cdk.aws_dynamodb import (
    Table, Attribute, AttributeType, BillingMode,
    ProjectionType, TableEncryption
)
from constructs import Construct


class DynamoDbStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        table = Table(
            self,
            "CustomerTable",
            partition_key=Attribute(name="id", type=AttributeType.STRING),
            billing_mode=BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            encryption=TableEncryption.AWS_MANAGED,
            removal_policy=RemovalPolicy.RETAIN,
        )

        table.add_global_secondary_index(
            index_name="CustomerIdIndex",
            partition_key=Attribute(name="customer_id", type=AttributeType.STRING),
            projection_type=ProjectionType.ALL,
        )