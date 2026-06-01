from aws_cdk import (
    Stack,
    RemovalPolicy,
    aws_dynamodb as dynamodb,
    aws_kms as kms,
)
from constructs import Construct


class DynamoDbStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        encryption_key = kms.Key(
            self,
            "TableEncryptionKey",
            description="CMK for DynamoDB table encryption",
            enable_key_rotation=True,
            removal_policy=RemovalPolicy.RETAIN,
        )

        table = dynamodb.Table(
            self,
            "Table",
            partition_key=dynamodb.Attribute(
                name="pk",
                type=dynamodb.AttributeType.STRING,
            ),
            sort_key=dynamodb.Attribute(
                name="sk",
                type=dynamodb.AttributeType.STRING,
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery_specification=dynamodb.PointInTimeRecoverySpecification(
                point_in_time_recovery_enabled=True,
            ),
            encryption=dynamodb.TableEncryption.CUSTOMER_MANAGED,
            encryption_key=encryption_key,
            removal_policy=RemovalPolicy.RETAIN,
            deletion_protection=True,
            contributor_insights_enabled=True,
            stream=dynamodb.StreamViewType.NEW_AND_OLD_IMAGES,
        )

        table.add_global_secondary_index(
            index_name="customer-id-index",
            partition_key=dynamodb.Attribute(
                name="customer_id",
                type=dynamodb.AttributeType.STRING,
            ),
            projection_type=dynamodb.ProjectionType.ALL,
        )

        self.table = table
        self.encryption_key = encryption_key