from aws_cdk import (
    Stack,
    RemovalPolicy
)
from aws_cdk import aws_dynamodb as dynamodb
from constructs import Construct

class DynamoDbStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        table = dynamodb.Table(
            self, "ProductionTable",
            partition_key=dynamodb.Attribute(
                name="id",
                type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            removal_policy=RemovalPolicy.RETAIN,
            encryption=dynamodb.TableEncryption.AWS_MANAGED
        )

        table.add_global_secondary_index(
            index_name="customer_id_index",
            partition_key=dynamodb.Attribute(
                name="customer_id",
                type=dynamodb.AttributeType.STRING
            ),
            projection_type=dynamodb.ProjectionType.ALL
        )