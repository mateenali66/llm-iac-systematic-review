from aws_cdk import (
    Stack,
    aws_ec2 as ec2,
    aws_elasticloadbalancingv2 as elbv2,
    aws_wafv2 as wafv2,
)
from constructs import Construct

class WafAlbStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create a VPC for the Application Load Balancer
        vpc = ec2.Vpc(
            self, "WafVpc",
            max_azs=2,
            nat_gateways=1,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="public-subnet",
                    subnet_type=ec2.SubnetType.PUBLIC,
                    cidr_mask=24
                ),
                ec2.SubnetConfiguration(
                    name="private-subnet",
                    subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS,
                    cidr_mask=24
                )
            ]
        )

        # Create an Application Load Balancer
        alb = elbv2.ApplicationLoadBalancer(
            self, "WafAlb",
            vpc=vpc,
            internet_facing=True
        )

        # Create the WAFv2 Web ACL
        web_acl = wafv