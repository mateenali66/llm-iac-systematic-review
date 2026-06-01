from aws_cdk import (
    aws_wafv2 as wafv2,
    aws_elasticloadbalancingv2 as elbv2,
    aws_ec2 as ec2,
    Stack,
    CfnOutput,
    RemovalPolicy,
    Duration
)
from constructs import Construct

class WafAlbStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # VPC with public subnets for ALB
        vpc = ec2.Vpc(
            self, "Vpc",
            max_azs=2,
            nat_gateways=0,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="Public",
                    subnet_type=ec2.SubnetType.PUBLIC,
                    cidr_mask=24
                )
            ]
        )

        # Security group for ALB
        alb_sg = ec2.SecurityGroup(
            self, "AlbSecurityGroup",
            vpc=vpc,
            description="Security group for ALB",
            allow_all_outbound=True
        )
        alb_sg.add_ingress_rule(
            peer=ec2.Peer.any_ipv4(),
            connection=ec2.Port.tcp(80),
            description="Allow HTTP from anywhere"
        )

        # Application Load Balancer
        alb = elbv2.ApplicationLoadBalancer(
            self, "ApplicationLoadBalancer",
            vpc=vpc,
            internet_facing=True,
            security_group=alb_sg,
            vpc_subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PUBLIC)
        )

        # Default listener (HTTP)
        listener = alb.add_listener(
            "HttpListener",
            port=80,
            open=True
        )

        # Default target group (empty, for demonstration)
        target_group = elbv2.ApplicationTargetGroup(
            self, "DefaultTargetGroup",
            vpc=vpc,
            port=80,
            protocol=elbv2.ApplicationProtocol.HTTP,
            target_type=elbv2.TargetType.INSTANCE,
            health_check=elbv2.HealthCheck(
                path="/",
                interval=Duration.seconds(30),
                timeout=Duration.seconds(5),
                healthy_threshold_count=2,
                unhealthy_threshold_count=2
            )
        )
        listener.add_target_groups("DefaultAction", target_groups=[target_group])

        # WAF Web ACL with managed rule groups
        web_acl = wafv2.CfnWebACL(
            self, "WebAcl",
            default_action=wafv2.CfnWebACL.DefaultActionProperty(
                allow={}
            ),
            scope="REGIONAL",
            visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                cloud_watch_metrics_enabled=True,
                metric_name="WebAclMetrics",
                sampled_requests_enabled=True
            ),
            rules=[
                # AWS Managed Core Rule Set
                wafv2.CfnWebACL.RuleProperty(
                    name="AWS-AWSManagedRulesCommonRuleSet",
                    priority=0,
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            name="AWSManagedRulesCommonRuleSet",
                            vendor_name="AWS"
                        )
                    ),
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(
                        none={}
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="AWSManagedRulesCommonRuleSet",
                        sampled_requests_enabled=True
                    )
                ),
                # AWS Managed SQL Injection Rule Set
                wafv2.CfnWebACL.RuleProperty(
                    name="AWS-AWSManagedRulesSQLiRuleSet",
                    priority=1,
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            name="AWSManagedRulesSQLiRuleSet",
                            vendor_name="AWS"
                        )
                    ),
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(
                        none={}
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="AWSManagedRulesSQLiRuleSet",
                        sampled_requests_enabled=True
                    )
                ),
                # Rate-based rule to mitigate DDoS
                wafv2.CfnWebACL.RuleProperty(
                    name="RateBasedRule",
                    priority=2,
                    statement=wafv2.CfnWebACL.StatementProperty(
                        rate_based_statement=wafv2.CfnWebACL.RateBasedStatementProperty(
                            limit=2000,
                            aggregate_key_type="IP"
                        )
                    ),
                    action=wafv2.CfnWebACL.RuleActionProperty(
                        block={}
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="RateBasedRule",
                        sampled_requests_enabled=True
                    )
                )
            ]
        )

        # Associate WAF ACL with ALB
        wafv2.CfnWebACLAssociation(
            self, "WebAclAssociation",
            resource_arn=alb.load_balancer_arn,
            web_acl_arn=web_acl.attr_arn
        )

        # Outputs
        CfnOutput(self, "AlbDnsName", value=alb.load_balancer_dns_name)
        CfnOutput(self, "WebAclArn", value=web_acl.attr_arn)