from aws_cdk import (
    Stack,
    Duration,
    CfnOutput,
    RemovalPolicy,
    aws_ec2 as ec2,
    aws_elasticloadbalancingv2 as elbv2,
    aws_wafv2 as wafv2,
    aws_logs as logs,
)
from constructs import Construct


class WafAlbStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # VPC
        vpc = ec2.Vpc(
            self,
            "Vpc",
            max_azs=2,
            nat_gateways=1,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="Public", subnet_type=ec2.SubnetType.PUBLIC, cidr_mask=24
                ),
                ec2.SubnetConfiguration(
                    name="Private",
                    subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS,
                    cidr_mask=24,
                ),
            ],
        )

        # ALB security group
        alb_sg = ec2.SecurityGroup(
            self,
            "AlbSg",
            vpc=vpc,
            description="Security group for ALB",
            allow_all_outbound=True,
        )
        alb_sg.add_ingress_rule(
            ec2.Peer.any_ipv4(), ec2.Port.tcp(443), "Allow HTTPS from internet"
        )

        # Application Load Balancer
        alb = elbv2.ApplicationLoadBalancer(
            self,
            "Alb",
            vpc=vpc,
            internet_facing=True,
            security_group=alb_sg,
            deletion_protection=True,
            drop_invalid_header_fields=True,
        )

        # Default target group (placeholder)
        target_group = elbv2.ApplicationTargetGroup(
            self,
            "DefaultTg",
            vpc=vpc,
            port=80,
            protocol=elbv2.ApplicationProtocol.HTTP,
            target_type=elbv2.TargetType.IP,
            health_check=elbv2.HealthCheck(
                path="/",
                healthy_http_codes="200-399",
                interval=Duration.seconds(30),
                timeout=Duration.seconds(5),
            ),
        )

        # HTTPS listener requires a certificate; using HTTP here for example completeness.
        # In production, replace with HTTPS listener + ACM certificate.
        listener = alb.add_listener(
            "HttpListener",
            port=80,
            protocol=elbv2.ApplicationProtocol.HTTP,
            default_target_groups=[target_group],
        )

        # WAF Web ACL with AWS Managed Rule Sets
        managed_rule_groups = [
            {
                "name": "AWSManagedRulesCommonRuleSet",
                "priority": 10,
                "vendor": "AWS",
                "metric": "AWSManagedRulesCommonRuleSet",
            },
            {
                "name": "AWSManagedRulesKnownBadInputsRuleSet",
                "priority": 20,
                "vendor": "AWS",
                "metric": "AWSManagedRulesKnownBadInputsRuleSet",
            },
            {
                "name": "AWSManagedRulesAmazonIpReputationList",
                "priority": 30,
                "vendor": "AWS",
                "metric": "AWSManagedRulesAmazonIpReputationList",
            },
            {
                "name": "AWSManagedRulesAnonymousIpList",
                "priority": 40,
                "vendor": "AWS",
                "metric": "AWSManagedRulesAnonymousIpList",
            },
            {
                "name": "AWSManagedRulesSQLiRuleSet",
                "priority": 50,
                "vendor": "AWS",
                "metric": "AWSManagedRulesSQLiRuleSet",
            },
            {
                "name": "AWSManagedRulesLinuxRuleSet",
                "priority": 60,
                "vendor": "AWS",
                "metric": "AWSManagedRulesLinuxRuleSet",
            },
        ]

        waf_rules = []
        for rg in managed_rule_groups:
            waf_rules.append(
                wafv2.CfnWebACL.RuleProperty(
                    name=rg["name"],
                    priority=rg["priority"],
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name=rg["vendor"],
                            name=rg["name"],
                        )
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name=rg["metric"],
                        sampled_requests_enabled=True,
                    ),
                )
            )

        # Rate-limit rule to mitigate DDoS / brute force
        waf_rules.append(
            wafv2.CfnWebACL.RuleProperty(
                name="RateLimitRule",
                priority=100,
                action=wafv2.CfnWebACL.RuleActionProperty(
                    block=wafv2.CfnWebACL.BlockActionProperty()
                ),
                statement=wafv2.CfnWebACL.StatementProperty(
                    rate_based_statement=wafv2.CfnWebACL.RateBasedStatementProperty(
                        limit=2000,
                        aggregate_key_type="IP",
                    )
                ),
                visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                    cloud