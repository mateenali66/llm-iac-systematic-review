from aws_cdk import (
    Stack,
    CfnOutput,
    Duration,
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

        alb_sg = ec2.SecurityGroup(
            self,
            "AlbSecurityGroup",
            vpc=vpc,
            description="Security group for ALB",
            allow_all_outbound=True,
        )
        alb_sg.add_ingress_rule(
            peer=ec2.Peer.any_ipv4(),
            connection=ec2.Port.tcp(443),
            description="Allow HTTPS from internet",
        )

        alb = elbv2.ApplicationLoadBalancer(
            self,
            "Alb",
            vpc=vpc,
            internet_facing=True,
            security_group=alb_sg,
            drop_invalid_header_fields=True,
            deletion_protection=True,
        )

        managed_rule_groups = [
            {
                "name": "AWSManagedRulesCommonRuleSet",
                "priority": 10,
                "vendor": "AWS",
                "metric": "AWSManagedRulesCommonRuleSetMetric",
            },
            {
                "name": "AWSManagedRulesKnownBadInputsRuleSet",
                "priority": 20,
                "vendor": "AWS",
                "metric": "AWSManagedRulesKnownBadInputsRuleSetMetric",
            },
            {
                "name": "AWSManagedRulesAmazonIpReputationList",
                "priority": 30,
                "vendor": "AWS",
                "metric": "AWSManagedRulesAmazonIpReputationListMetric",
            },
            {
                "name": "AWSManagedRulesSQLiRuleSet",
                "priority": 40,
                "vendor": "AWS",
                "metric": "AWSManagedRulesSQLiRuleSetMetric",
            },
            {
                "name": "AWSManagedRulesLinuxRuleSet",
                "priority": 50,
                "vendor": "AWS",
                "metric": "AWSManagedRulesLinuxRuleSetMetric",
            },
            {
                "name": "AWSManagedRulesAnonymousIpList",
                "priority": 60,
                "vendor": "AWS",
                "metric": "AWSManagedRulesAnonymousIpListMetric",
            },
        ]

        rules = []
        for rg in managed_rule_groups:
            rules.append(
                wafv2.CfnWebACL.RuleProperty(
                    name=rg["name"],
                    priority=rg["priority"],
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name=rg["vendor"],
                            name=rg["name"],
                        )
                    ),
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        sampled_requests_enabled=True,
                        cloud_watch_metrics_enabled=True,
                        metric_name=rg["metric"],
                    ),
                )
            )

        rules.append(
            wafv2.CfnWebACL.RuleProperty(
                name="RateLimitRule",
                priority=100,
                action=wafv2.CfnWebACL.RuleActionProperty(block={}),
                statement=wafv2.CfnWebACL.StatementProperty(
                    rate_based_statement=wafv2.CfnWebACL.RateBasedStatementProperty(
                        limit=2000,
                        aggregate_key_type="IP",
                    )
                ),
                visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                    sampled_requests_enabled=True,
                    cloud_watch_metrics_enabled=True,
                    metric_name="RateLimitRuleMetric",
                ),
            )
        )

        web_acl = wafv2.CfnWebACL(
            self,
            "WebAcl",
            default_action=wafv2.CfnWebACL.DefaultActionProperty(allow={}),
            scope="REGIONAL",
            visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                sampled_requests_enabled=True,
                cloud_watch_metrics_enabled=True,
                metric_name="WebAclMetric",
            ),
            name="alb-web-acl",
            description="WAF Web ACL with AWS managed rule sets for ALB protection",
            rules=rules,
        )

        log_group = logs.LogGroup(
            self,
            "WafLogGroup",
            log_group_name=f"aws-waf-logs-{construct_id.lower()}",
            retention=logs.RetentionDays.ONE_MONTH,
            removal_policy=RemovalPolicy.RETAIN,
        )