import aws_cdk as cdk
from aws_cdk import (
    aws_ec2 as ec2,
    aws_iam as iam,
)

class VPCStack(cdk.Stack):
    def __init__(self, scope: cdk.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        self.vpc = ec2.Vpc(
            self, 'VPC',
            cidr='10.0.0.0/16',
            max_azs=2,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name='public-subnet',
                    subnet_type=ec2.SubnetType.PUBLIC
                ),
                ec2.SubnetConfiguration(
                    name='private-subnet',
                    subnet_type=ec2.SubnetType.PRIVATE_WITH_NAT
                ),
                ec2.SubnetConfiguration(
                    name='isolated-subnet',
                    subnet_type=ec2.SubnetType.PRIVATE_ISOLATED
                )
            ],
            nat_gateways=2,
        )

        self.s3_vpc_endpoint = self.vpc.add_gateway_endpoint(
            'S3Endpoint',
            service=ec2.GatewayVpcEndpointAwsService.S3,
            subnets=[ec2.SubnetType.PRIVATE_WITH_NAT]
        )

        self.dynamodb_vpc_endpoint = self.vpc.add_interface_endpoint(
            'DynamoDBEndpoint',
            service=ec2.InterfaceVpcEndpointAwsService.DYNAMODB,
            subnets=[ec2.SubnetType.PRIVATE_WITH_NAT],
            security_groups=[ec2.SecurityGroup(
                self, 'DynamoDBEndpointSG',
                vpc=self.vpc,
                description='Security group for DynamoDB VPC endpoint'
            )]
        )

        self.dynamodb_vpc_endpoint.node.add_dependency(self.vpc)