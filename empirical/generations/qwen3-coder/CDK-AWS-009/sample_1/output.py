from aws_cdk import (
    Stack,
    aws_wafv2 as wafv2,
    aws_elasticloadbalancingv2 as elbv2,
    aws_iam as iam,
    Duration,
    CfnOutput
)
from constructs import Construct

class WafAclStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create the WAF Web ACL
        web_acl = wafv2.CfnWebACL(
            self, "WebAcl",
            scope="REGIONAL",
            default_action=wafv2.CfnWebACL.DefaultActionProperty(
                allow={}
            ),
            rules=[
                # AWS Managed Rules - Core Rule Set
                wafv2.CfnWebACL.RuleProperty(
                    name="AWSManagedRulesCommonRuleSet",
                    priority=1,
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesCommonRuleSet"
                        )
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="AWSManagedRulesCommonRuleSetMetric",
                        sampled_requests_enabled=True
                    )
                ),
                # AWS Managed Rules - Known Bad Inputs Rule Set
                wafv2.CfnWebACL.RuleProperty(
                    name="AWSManagedRulesKnownBadInputsRuleSet",
                    priority=2,
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesKnownBadInputsRuleSet"
                        )
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="AWSManagedRulesKnownBadInputsRuleSetMetric",
                        sampled_requests_enabled=True
                    )
                ),
                # AWS Managed Rules - SQL Injection Rule Set
                wafv2.CfnWebACL.RuleProperty(
                    name="AWSManagedRulesSQLiRuleSet",
                    priority=3,
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesSQLiRuleSet"
                        )
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="AWSManagedRulesSQLiRuleSetMetric",
                        sampled_requests_enabled=True
                    )
                )
            ],
            visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                cloud_watch_metrics_enabled=True,
                metric_name="WebAclMetric",
                sampled_requests_enabled=True
            )
        )

        # Create Application Load Balancer
        alb = elbv2.ApplicationLoadBalancer(
            self, "ALB",
            internet_facing=True,
            vpc=self.vpc_from_lookup()
        )

        # Associate WAF ACL with ALB
        wafv2.CfnWebACLAssociation(
            self, "WebACLAssociation",
            resource_arn=alb.load_balancer_arn,
            web_acl_arn=web_acl.attr_arn
        )

        # Output the Web ACL ARN
        CfnOutput(
            self, "WebAclArn",
            value=web_acl.attr_arn,
            export_name="WebAclArn"
        )

    def vpc_from_lookup(self):
        # This is a placeholder - in a real implementation you would either:
        # 1. Import an existing VPC using ec2.Vpc.from_lookup()
        # 2. Create a new VPC using ec2.Vpc()
        # For this example we'll create a minimal VPC
        from aws_cdk import aws_ec2 as ec2
        return ec2.Vpc(self, "VPC", max_azs=2)