from aws_cdk import (
    App,
    Stack,
    RemovalPolicy,
    aws_ec2 as ec2,
    aws_logs as logs,
    aws_kms as kms,
)
from constructs import Construct


class NetworkStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        vpc = ec2.Vpc(
            self,
            "Vpc",
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
        )

        vpc.add_gateway_endpoint(
            "S3Endpoint",
            service=ec2.GatewayVpcEndpointAwsService.S3,
            subnets=[ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS)],
        )

        vpc.add_gateway_endpoint(
            "DynamoDbEndpoint",
            service=ec2.GatewayVpcEndpointAwsService.DYNAMODB,
            subnets=[ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS)],
        )

        flow_logs_key = kms.Key(
            self,
            "VpcFlowLogsKey",
            enable_key_rotation=True,
            removal_policy=RemovalPolicy.RETAIN,
        )

        flow_logs_group = logs.LogGroup(
            self,
            "VpcFlowLogsGroup",
            retention=logs.RetentionDays.ONE_YEAR,
            encryption_key=flow_logs_key,
            removal_policy=RemovalPolicy.RETAIN,
        )

        ec2.FlowLog(
            self,
            "VpcFlowLogs",
            resource_type=ec2.FlowLogResourceType.from_vpc(vpc),
            traffic_type=ec2.FlowLogTrafficType.ALL,
            destination=ec2.FlowLogDestination.to_cloud_watch_logs(flow_logs_group),
        )


app = App()
NetworkStack(app, "NetworkStack")
app.synth()