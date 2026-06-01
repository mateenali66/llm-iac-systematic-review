import aws_cdk as cdk
from aws_cdk import aws_dynamodb as dynamodb

class DynamoDBStack(cdk.Stack):
    def __init__(self, scope: cdk.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        table = dynamodb.Table(
            self, 'Table',
            table_name='customer-table',
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            partition_key=dynamodb.Attribute(
                name='id',
                type=dynamodb.AttributeType.STRING
            ),
            sort_key=dynamodb.Attribute(
                name='sort_key',
                type=dynamodb.AttributeType.STRING
            ),
            global_secondary_indexes=[
                dynamodb.GlobalSecondaryIndex(
                    index_name='customer_id_index',
                    partition_key=dynamodb.Attribute(
                        name='customer_id',
                        type=dynamodb.AttributeType.STRING
                    ),
                    projection_type=dynamodb.ProjectionType.ALL
                )
            ]
        )

        cdk.CfnOutput(
            self, 'TableName',
            value=table.table_name,
            description='The name of the DynamoDB table'
        )