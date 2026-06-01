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

        # Reference an existing ALB (must be created separately or passed as parameter)
        # For demonstration, we create a placeholder ALB reference.
        # In production, you would import the ALB ARN via context or SSM.
        alb_arn = self.node.try_get_context("alb_arn")
        if not alb_arn:
            raise ValueError("Context variable 'alb_arn' must be provided (e.g., cdk deploy -c alb_arn=arn:aws:elasticloadbalancing:...)")

        # Import the ALB by ARN
        alb = elbv2.ApplicationLoadBalancer.from_lookup(
            self, "Alb",
            load_balancer_arn=alb_arn,
        )

        # Create the WAF Web ACL with managed rule groups
        web_acl = wafv2.CfnWebACL(
            self, "WebAcl",
            default_action=wafv2.CfnWebACL.DefaultActionProperty(
                allow={}  # Allow by default, block via rules
            ),
            scope="REGIONAL",  # ALB is regional
            visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                cloud_watch_metrics_enabled=True,
                metric_name="WafWebAcl",
                sampled_requests_enabled=True,
            ),
            rules=[
                # AWS Managed Core Rule Set (baseline protections)
                wafv2.CfnWebACL.RuleProperty(
                    name="AWS-AWSManagedRulesCommonRuleSet",
                    priority=0,
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesCommonRuleSet",
                        )
                    ),
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(
                        none={}
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="AWSManagedRulesCommonRuleSet",
                        sampled_requests_enabled=True,
                    ),
                ),
                # AWS Managed SQL Injection Rule Set
                wafv2.CfnWebACL.RuleProperty(
                    name="AWS-AWSManagedRulesSQLiRuleSet",
                    priority=1,
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesSQLiRuleSet",
                        )
                    ),
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(
                        none={}
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="AWSManagedRulesSQLiRuleSet",
                        sampled_requests_enabled=True,
                    ),
                ),
                # AWS Managed Known Bad Inputs Rule Set
                wafv2.CfnWebACL.RuleProperty(
                    name="AWS-AWSManagedRulesKnownBadInputsRuleSet",
                    priority=2,
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesKnownBadInputsRuleSet",
                        )
                    ),
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(
                        none={}
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="AWSManagedRulesKnownBadInputsRuleSet",
                        sampled_requests_enabled=True,
                    ),
                ),
            ],
        )

        # Associate the WAF ACL with the ALB
        wafv2.CfnWebACLAssociation(
            self, "WebAclAssociation",
            resource_arn=alb.load_balancer_arn,
            web_acl_arn=web_acl.attr_arn,
        )

        # Output the Web ACL ARN
        CfnOutput(
            self, "WebAclArn",
            value=web_acl.attr_arn,
            description="ARN of the WAF Web ACL",
        )