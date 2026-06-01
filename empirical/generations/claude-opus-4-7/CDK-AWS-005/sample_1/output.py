from aws_cdk import (
    Stack,
    aws_ec2 as ec2,
    Tags,
)
from constructs import Construct


class NetworkStack(Stack):
    """Production-grade VPC stack with public/private subnets across 2 AZs,
    HA NAT gateways, and gateway VPC endpoints for S3 and DynamoDB."""

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.vpc = ec2.Vpc(
            self,
            "Vpc",
            ip_addresses=ec2.IpAddresses.cidr("10.0.0.0/16"),
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
            gateway_endpoints={
                "S3": ec2.GatewayVpcEndpointOptions(
                    service=ec2.GatewayVpcEndpointAwsService.S3,
                    subnets=[
                        ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS),
                        ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_ISOLATED),
                    ],
                ),
                "DynamoDB": ec2.GatewayVpcEndpointOptions(
                    service=ec2.GatewayVpcEndpointAwsService.DYNAMODB,
                    subnets=[
                        ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS),
                        ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_ISOLATED),
                    ],
                ),
            },
        )

        # Enable VPC flow logs to CloudWatch for security/audit
        self.vpc.add_flow_log(
            "FlowLogCloudWatch",
            destination=ec2.FlowLogDestination.to_cloud_watch_logs(),
            traffic_type=ec2.FlowLogTrafficType.ALL,
        )

        # Restrict default security group (best practice / CIS benchmark)
        default_sg = ec2.SecurityGroup.from_security_group_id(
            self, "DefaultSg", self.vpc.vpc_default_security_group
        )
        # Note: default SG ingress/egress should be removed via custom resource or manually;
        # CDK creates additional SGs as needed, leaving default unused.

        Tags.of(self.vpc).add("Name", f"{construct_id}-vpc")
        Tags.of(self.vpc).add("ManagedBy", "CDK")