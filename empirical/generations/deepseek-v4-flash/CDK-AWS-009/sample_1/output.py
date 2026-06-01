from aws_cdk import (
    aws_wafv2 as wafv2,
    aws_elasticloadbalancingv2 as elbv2,
    Stack,
    CfnOutput,
    RemovalPolicy,
)
from constructs import Construct

class WafAlbStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create the WAF Web ACL with managed rule groups
        web_acl = wafv2.CfnWebACL(
            self,
            "WebACL",
            default_action=wafv2.CfnWebACL.DefaultActionProperty(
                allow={}
            ),
            scope="REGIONAL",
            visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                cloud_watch_metrics_enabled=True,
                metric_name="WebACLMetric",
                sampled_requests_enabled=True,
            ),
            rules=[
                # AWS Managed Core Rule Set
                wafv2.CfnWebACL.RuleProperty(
                    name="AWS-AWSManagedRulesCommonRuleSet",
                    priority=0,
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            name="AWSManagedRulesCommonRuleSet",
                            vendor_name="AWS",
                        )
                    ),
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(
                        none={}
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="AWSManagedRulesCommonRuleSetMetric",
                        sampled_requests_enabled=True,
                    ),
                ),
                # AWS Managed SQL Injection Rule Set
                wafv2.CfnWebACL.RuleProperty(
                    name="AWS-AWSManagedRulesSQLiRuleSet",
                    priority=1,
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            name="AWSManagedRulesSQLiRuleSet",
                            vendor_name="AWS",
                        )
                    ),
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(
                        none={}
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="AWSManagedRulesSQLiRuleSetMetric",
                        sampled_requests_enabled=True,
                    ),
                ),
                # AWS Managed Known Bad Inputs Rule Set
                wafv2.CfnWebACL.RuleProperty(
                    name="AWS-AWSManagedRulesKnownBadInputsRuleSet",
                    priority=2,
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            name="AWSManagedRulesKnownBadInputsRuleSet",
                            vendor_name="AWS",
                        )
                    ),
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(
                        none={}
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="AWSManagedRulesKnownBadInputsRuleSetMetric",
                        sampled_requests_enabled=True,
                    ),
                ),
            ],
        )

        # Create an Application Load Balancer (example)
        vpc = ec2.Vpc(self, "Vpc", max_azs=2)
        alb = elbv2.ApplicationLoadBalancer(
            self,
            "ALB",
            vpc=vpc,
            internet_facing=True,
            removal_policy=RemovalPolicy.DESTROY,
        )

        # Associate WAF Web ACL with the ALB
        wafv2.CfnWebACLAssociation(
            self,
            "WebACLAssociation",
            resource_arn=alb.load_balancer_arn,
            web_acl_arn=web_acl.attr_arn,
        )

        # Outputs
        CfnOutput(self, "WebACLArn", value=web_acl.attr_arn)
        CfnOutput(self, "ALBArn", value=alb.load_balancer_arn)
        CfnOutput(self, "ALBDnsName", value=alb.load_balancer_dns_name)