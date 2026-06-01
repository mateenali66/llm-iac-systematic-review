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
            attribute_definitions=[
                dynamodb.Attribute(
                    name='id',
                    type=dynamodb.AttributeType.STRING
                ),
                dynamodb.Attribute(
                    name='customer_id',
                    type=dynamodb.AttributeType.STRING
                )
            ],
            key_schema=[
                dynamodb.KeySchema(
                    attribute_name='id',
                    key_type=dynamodb.KeyType.HASH
                )
            ],
            global_secondary_indexes=[
                dynamodb.GlobalSecondaryIndex(
                    index_name='customer_id_index',
                    key_schema=[
                        dynamodb.KeySchema(
                            attribute_name='customer_id',
                            key_type=dynamodb.KeyType.HASH
                        )
                    ],
                    projection_type=dynamodb.ProjectionType.ALL
                )
            ]
        )

        cdk.CfnOutput(
            self, 'TableName',
            value=table.table_name,
            description='The name of the DynamoDB table'
        )