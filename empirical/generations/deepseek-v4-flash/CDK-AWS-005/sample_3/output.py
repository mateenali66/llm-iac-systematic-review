from aws_cdk import (
    aws_ec2 as ec2,
    Stack,
    aws_iam as iam,
    CfnOutput,
)
from constructs import Construct

class VpcStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create VPC with public/private subnets across 2 AZs, 2 NAT gateways for HA
        self.vpc = ec2.Vpc(
            self, "Vpc",
            max_azs=2,
            nat_gateways=2,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="Public",
                    subnet_type=ec2.SubnetType.PUBLIC,
                    cidr_mask=24,
                ),
                ec2.SubnetConfiguration(
                    name="Private",
                    subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS,
                    cidr_mask=24,
                ),
            ],
            # Ensure each AZ gets its own NAT gateway for HA
            nat_gateway_provider=ec2.NatProvider.gateway(),
            # Enable DNS hostnames and DNS support for VPC endpoints
            enable_dns_hostnames=True,
            enable_dns_support=True,
        )

        # VPC Endpoint for S3 (Gateway type)
        self.vpc.add_gateway_endpoint(
            "S3Endpoint",
            service=ec2.GatewayVpcEndpointAwsService.S3,
            subnets=[ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS)],
        )

        # VPC Endpoint for DynamoDB (Gateway type)
        self.vpc.add_gateway_endpoint(
            "DynamoDBEndpoint",
            service=ec2.GatewayVpcEndpointAwsService.DYNAMODB,
            subnets=[ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS)],
        )

        # Output VPC ID for reference
        CfnOutput(
            self, "VpcId",
            value=self.vpc.vpc_id,
            description="VPC ID",
        )

        # Output public and private subnet IDs
        CfnOutput(
            self, "PublicSubnetIds",
            value=",".join(subnet.subnet_id for subnet in self.vpc.public_subnets),
            description="Public Subnet IDs",
        )
        CfnOutput(
            self, "PrivateSubnetIds",
            value=",".join(subnet.subnet_id for subnet in self.vpc.private_subnets),
            description="Private Subnet IDs",
        )