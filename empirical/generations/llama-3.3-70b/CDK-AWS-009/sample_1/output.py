import aws_cdk as cdk
from aws_cdk import (
    aws_wafv2 as wafv2,
    aws_elasticloadbalancingv2 as elbv2,
)

class WafAclStack(cdk.Stack):
    def __init__(self, scope: cdk.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Create an Application Load Balancer
        alb = elbv2.ApplicationLoadBalancer(
            self, "ALB",
            vpc=cdk.aws_ec2.Vpc(self, "VPC", max_azs=3),
            internet_facing=True,
        )

        # Create a WAF web ACL
        web_acl = wafv2.CfnWebACL(
            self, "WebACL",
            default_action=wafv2.CfnWebACL.DefaultActionProperty(
                allow={}
            ),
            scope="REGIONAL",
            visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                cloud_watch_metrics_enabled=True,
                metric_name="WebACL",
                sampled_requests_enabled=True,
            ),
        )

        # Create managed rule sets
        aws_managed_rules = wafv2.CfnWebACL.RuleProperty(
            name="AWSManagedRules",
            priority=1,
            override_action=wafv2.CfnWebACL.OverrideActionProperty(
                none={}
            ),
            rule_id="AWSManagedRulesCommonRuleSet",
            visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                cloud_watch_metrics_enabled=True,
                metric_name="AWSManagedRules",
                sampled_requests_enabled=True,
            ),
        )

        ip_reputation = wafv2.CfnWebACL.RuleProperty(
            name="IPReputation",
            priority=2,
            override_action=wafv2.CfnWebACL.OverrideActionProperty(
                none={}
            ),
            rule_id="AWSManagedRulesAmazonIpReputationRuleSet",
            visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                cloud_watch_metrics_enabled=True,
                metric_name="IPReputation",
                sampled_requests_enabled=True,
            ),
        )

        # Add managed rule sets to the WAF web ACL
        web_acl.add_property_override(
            "Rules",
            [aws_managed_rules, ip_reputation],
        )

        # Associate the WAF web ACL with the Application Load Balancer
        wafv2.CfnWebACLAssociation(
            self, "WebACLAssociation",
            resource_arn=alb.load_balancer_arn,
            web_acl_arn=web_acl.attr_arn,
        )