from aws_cdk import (
    Stack,
    Tags,
    aws_ec2 as ec2,
)
from constructs import Construct


class NetworkStack(Stack):
    """Production-ready VPC with public/private subnets across 2 AZs,
    HA NAT Gateways, and Gateway VPC Endpoints for S3 and DynamoDB."""

    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        cidr: str = "10.0.0.0/16",
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.vpc = ec2.Vpc(
            self,
            "Vpc",
            ip_addresses=ec2.IpAddresses.cidr(cidr),
            max_azs=2,
            nat_gateways=2,
            enable_dns_hostnames=True,
            enable_dns_support=True,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="Public",
                    subnet_type=ec2.SubnetType.PUBLIC,
                    cidr_mask=24,
                    map_public_ip_on_launch=False,
                ),
                ec2.SubnetConfiguration(
                    name="Private",
                    subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS,
                    cidr_mask=24,
                ),
                ec2.SubnetConfiguration(
                    name="Isolated",
                    subnet_type=ec2.SubnetType.PRIVATE_ISOLATED,
                    cidr_mask=24,
                ),
            ],
        )

        # VPC Flow Logs to CloudWatch for security/auditing
        self.vpc.add_flow_log(
            "FlowLogCloudWatch",
            traffic_type=ec2.FlowLogTrafficType.ALL,
        )

        # Gateway endpoints (no hourly cost) for S3 and DynamoDB
        self.s3_endpoint = self.vpc.add_gateway_endpoint(
            "S3Endpoint",
            service=ec2.GatewayVpcEndpointAwsService.S3,
            subnets=[
                ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS),
                ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_ISOLATED),
            ],
        )

        self.dynamodb_endpoint = self.vpc.add_gateway_endpoint(
            "DynamoDbEndpoint",
            service=ec2.GatewayVpcEndpointAwsService.DYNAMODB,
            subnets=[
                ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS),
                ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_ISOLATED),
            ],
        )

        Tags.of(self).add("ManagedBy", "CDK")
        Tags.of(self).add("Component", "Network")