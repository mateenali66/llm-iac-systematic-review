from aws_cdk import (
    App,
    Stack,
    CfnOutput,
    aws_ec2 as ec2,
)
from constructs import Construct

class ProductionVpcStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        vpc = ec2.Vpc(
            self,
            "HighAvailabilityVpc",
            ip_addresses=ec2.IpAddresses.cidr("10.0.0.0/16"),
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
            gateway_endpoints={
                "S3": ec2.GatewayVpcEndpointOptions(
                    service=ec2.GatewayVpcEndpointAwsService.S3
                ),
                "DynamoDB": ec2.GatewayVpcEndpointOptions(
                    service=ec2.GatewayVpcEndpointAwsService.DYNAMODB
                )
            },
            flow_logs={
                "DefaultFlowLog": ec2.FlowLogOptions(
                    destination=ec2.FlowLogDestination.to_cloud_watch_logs()
                )
            }
        )

        self.vpc = vpc

        CfnOutput(self, "VpcId",
            value=vpc.vpc_id,
            description="ID of the production VPC"
        )

        CfnOutput(self, "PublicSubnetIds",
            value=",".join([s.subnet_id for s in vpc.public_subnets]),
            description="Comma-separated list of public subnet IDs"
        )

        CfnOutput(self, "PrivateSubnetIds",
            value=",".join([s.subnet_id for s in vpc.private_subnets]),
            description="Comma-separated list of private subnet IDs"
        )