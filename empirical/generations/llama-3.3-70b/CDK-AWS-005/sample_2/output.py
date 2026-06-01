import aws_cdk as cdk
from aws_cdk import (
    aws_ec2 as ec2,
    aws_iam as iam,
    aws_s3 as s3,
    aws_dynamodb as dynamodb
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
                    name='private-isolated-subnet',
                    subnet_type=ec2.SubnetType.PRIVATE_ISOLATED
                )
            ]
        )

        self.nat_gateways = []
        for i, az in enumerate(self.vpc.availability_zones):
            nat_gateway = ec2.NatGateway(
                self, f'NATGateway{i}',
                subnet=self.vpc.public_subnets[i]
            )
            self.nat_gateways.append(nat_gateway)

        self.s3_vpc_endpoint = self.vpc.add_gateway_endpoint(
            'S3Endpoint',
            service=ec2.GatewayVpcEndpointAwsService.S3
        )

        self.dynamodb_vpc_endpoint = self.vpc.add_interface_endpoint(
            'DynamoDBEndpoint',
            service=ec2.InterfaceVpcEndpointAwsService.DYNAMODB
        )

        self.dynamodb_vpc_endpoint.add_to_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                principals=[iam.AnyPrincipal()],
                actions=['dynamodb:*'],
                resources=['*']
            )
        )

        self.s3_vpc_endpoint.add_to_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                principals=[iam.AnyPrincipal()],
                actions=['s3:*'],
                resources=['*']
            )
        )