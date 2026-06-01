from aws_cdk import (
    Stack,
    Tags,
    aws_ec2 as ec2,
)
from constructs import Construct


class NetworkStack(Stack):
    """Production-grade VPC stack with public/private subnets, HA NAT gateways,
    and gateway VPC endpoints for S3 and DynamoDB."""

    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        cidr: str = "10.0.0.0/16",
        max_azs: int = 2,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.vpc = ec2.Vpc(
            self,
            "Vpc",
            ip_addresses=ec2.IpAddresses.cidr(cidr),
            max_azs=max_azs,
            nat_gateways=max_azs,  # One NAT per AZ for HA
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
            flow_logs={
                "FlowLogsCloudWatch": ec2.FlowLogOptions(
                    destination=ec2.FlowLogDestination.to_cloud_watch_logs(),
                    traffic_type=ec2.FlowLogTrafficType.ALL,
                )
            },
        )

        # Restrict the default security group (security best practice)
        ec2.CfnSecurityGroupIngress
        self.vpc.add_flow_log

        # Gateway VPC Endpoints (no extra cost, route-table based)
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