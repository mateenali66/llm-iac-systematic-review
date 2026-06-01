from aws_cdk import App, Stack, aws_ec2 as ec2, aws_elasticloadbalancingv2 as elbv2, aws_wafv2 as wafv2
from constructs import Construct

class WafAlbStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        vpc = ec2.Vpc(
            self, "Vpc",
            max_azs=2,
            nat_gateways=0,
            subnet_configuration=[
                ec2.SubnetConfiguration(name="Public", subnet_type=ec2.SubnetType.PUBLIC, cidr_mask=24)
            ]
        )

        alb_sg = ec2.SecurityGroup(
            self, "AlbSecurityGroup",
            vpc=vpc,
            description="Security group for ALB",
            allow_all_outbound=True
        )
        alb_sg.add_ingress_rule(ec2.Peer.any_ipv4(), ec2.Port.tcp(443), "Allow HTTPS")

        alb = elbv2.ApplicationLoadBalancer(
            self, "ApplicationLoadBalancer",
            vpc=vpc,
            internet_facing=True,
            security_group=alb_sg,
            vpc_subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PUBLIC)
        )

        elbv2.ApplicationListener(
            self, "HttpsListener",
            load_balancer=alb,
            port=443,
            protocol=elbv2.ApplicationProtocol.HTTPS,
            default_action=elbv2.ListenerAction.fixed_response(
                status_code=200,
                content_type="text/plain",
                message_body="OK"
            )
        )

        web_acl = wafv2.CfnWebACL(
            self, "WebACL",
            name="ProductionWebACL",
            scope="REGIONAL",
            default_action=wafv2.CfnWebACL.DefaultActionProperty(allow={}),
            visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                cloud_watch_metrics_enabled=True,
                metric_name="ProductionWebACL",
                sampled_requests_enabled=True
            ),
            rules=[
                wafv2.CfnWebACL.RuleProperty(
                    name="AWSManagedCommonRuleSet",
                    priority=10,
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesCommonRuleSet"
                        )
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="CommonRuleSet",
                        sampled_requests_enabled=True
                    )
                ),
                wafv2.CfnWebACL.RuleProperty(
                    name="AWSManagedSQLiRuleSet",
                    priority=20,
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesSQLiRuleSet"
                        )
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="SQLiRuleSet",
                        sampled_requests_enabled=True
                    )
                )
            ]
        )

        wafv2.CfnWebACLAssociation(
            self, "WebACLAssociation",
            resource_arn=alb.load_balancer_arn,
            web_acl_arn=web_acl.attr_arn
        )


app = App()
WafAlbStack(app, "WafAlbStack")
app.synth()