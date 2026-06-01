import aws_cdk as cdk
from aws_cdk import aws_ec2 as ec2
from constructs import Construct

class ProductionVpcStack(cdk.Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Define the VPC with public and private subnets across 2 AZs
        # NAT Gateways are created in each AZ for high availability.
        vpc = ec2.Vpc(
            self,
            "ProductionVPC",
            ip_addresses=ec2.IpAddresses.cidr("10.0.0.0/16"),
            max_azs=2,
            nat_gateways=2,
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
            # Enable VPC Flow Logs for security monitoring and troubleshooting
            flow_logs={
                "DefaultFlowLog": ec2.FlowLogOptions()
            }
        )

        # Add a Gateway VPC Endpoint for S3 to allow private access
        # This is more cost-effective and secure than using NAT Gateways for S3 traffic.
        vpc.add_gateway_endpoint(
            "S3GatewayEndpoint",
            service=ec2.GatewayVpcEndpointAwsService.S3
        )

        # Add a Gateway VPC Endpoint for DynamoDB for private access
        # This improves security and can reduce data transfer costs.
        vpc.add_gateway_endpoint(
            "DynamoDBGatewayEndpoint",
            service=ec2.GatewayV