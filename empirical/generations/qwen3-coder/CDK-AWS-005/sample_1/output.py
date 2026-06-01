from aws_cdk import (
    Stack,
    aws_ec2 as ec2,
    RemovalPolicy
)
from constructs import Construct

class VpcStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create VPC with public and private subnets across 2 AZs
        vpc = ec2.Vpc(
            self, "ProductionVPC",
            max_azs=2,
            cidr="10.0.0.0/16",
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="Public",
                    subnet_type=ec2.SubnetType.PUBLIC,
                    cidr_mask=24
                ),
                ec2.SubnetConfiguration(
                    name="Private",
                    subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS,
                    cidr_mask=24
                )
            ],
            nat_gateways=2,
            enable_dns_hostnames=True,
            enable_dns_support=True
        )

        # Add S3 Gateway endpoint
        s3_endpoint = vpc.add_gateway_endpoint(
            "S3Endpoint",
            service=ec2.GatewayVpcEndpointAwsService.S3
        )

        # Add DynamoDB Gateway endpoint
        dynamodb_endpoint = vpc.add_gateway_endpoint(
            "DynamoDBEndpoint",
            service=ec2.GatewayVpcEndpointAwsService.DYNAMODB
        )

        # Apply secure default policies to endpoints
        s3_endpoint.add_to_policy(
            ec2.GatewayVpcEndpointPolicyStatement(
                principals=[ec2.AnyPrincipal()],
                actions=["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
                resources=["arn:aws:s3:::*/*"]
            )
        )

        dynamodb_endpoint.add_to_policy(
            ec2.GatewayVpcEndpointPolicyStatement(
                principals=[ec2.AnyPrincipal()],
                actions=["dynamodb:Query", "dynamodb:Scan", "dynamodb:GetItem", 
                        "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"],
                resources=["arn:aws:dynamodb:*:*:table/*"]
            )
        )