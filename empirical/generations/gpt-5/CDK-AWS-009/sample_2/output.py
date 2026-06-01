from aws_cdk import (
    Stack,
    RemovalPolicy,
    CfnOutput,
    aws_ec2 as ec2,
    aws_elasticloadbalancingv2 as elbv2,
    aws_wafv2 as wafv2,
    aws_s3 as s3,
    aws_kinesisfirehose as firehose,
    aws_iam as iam,
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
        )

        alb_sg = ec2.SecurityGroup(
            self,
            "AlbSecurityGroup",
            vpc=vpc,
            description="Security group for ALB allowing HTTP/HTTPS",
            allow_all_outbound=True,
        )
        alb_sg.add_ingress_rule(ec2.Peer.any_ipv4(), ec2.Port.tcp(80), "Allow HTTP")
        alb_sg.add_ingress_rule(ec2.Peer.any_ipv6(), ec2.Port.tcp(80), "Allow HTTP IPv6")
        alb_sg.add_ingress_rule(ec2.Peer.any_ipv4(), ec2.Port.tcp(443), "Allow HTTPS")
        alb_sg.add_ingress_rule(ec2.Peer.any_ipv6(), ec2.Port.tcp(443), "Allow HTTPS IPv6")

        alb = elbv2.ApplicationLoadBalancer(
            self,
            "Alb",
            vpc=vpc,
            internet_facing=True,
            security_group=alb_sg,
            vpc_subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PUBLIC),
        )

        http_listener = alb.add_listener("HttpListener", port=80, open=True)
        http_listener.add_action(
            "DefaultFixedResponse",
            action=elbv2.ListenerAction.fixed_response(
                status_code=200,
                content_type="text/plain",
                message_body="OK",
            ),
        )

        web_acl = wafv2.CfnWebACL(
            self,
            "WebAcl",
            name=f"{Stack.of(self).stack_name}-web-acl",
            scope="REGIONAL",
            default_action=wafv2.CfnWebACL.DefaultActionProperty(allow={} ),
            visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                cloud_watch_metrics_enabled=True,
                metric_name=f"{Stack.of(self).stack_name}-web-acl",
                sampled_requests_enabled=True,
            ),
            rules=[
                wafv2.CfnWebACL.RuleProperty(
                    name="AWS-AWSManagedRulesCommonRuleSet",
                    priority=0,
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesCommonRuleSet",
                        )
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="aws-commonruleset",
                        sampled_requests_enabled=True,
                    ),
                ),
                wafv2.CfnWebACL.RuleProperty(
                    name="AWS-AWSManagedRulesKnownBadInputsRuleSet",
                    priority=1,
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesKnownBadInputsRuleSet",
                        )
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="aws-knownbadinputs",
                        sampled_requests_enabled=True,
                    ),
                ),
                wafv2.CfnWebACL.RuleProperty(
                    name="AWS-AWSManagedRulesSQLiRuleSet",
                    priority=2,
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesSQLiRuleSet",
                        )
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="aws-sqli",
                        sampled_requests_enabled=True,
                    ),
                ),
                wafv2.CfnWebACL.RuleProperty(
                    name="AWS-AWSManagedRulesAmazonIpReputationList",
                    priority=3,
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesAmazonIpReputationList",
                        )
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="aws-ipreputation",
                        sampled_requests_enabled=True,
                    ),
                ),
                wafv2.CfnWebACL.RuleProperty(
                    name="AWS-AWSManagedRulesAnonymousIpList",
                    priority=4,
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesAnonymousIpList",
                        )
                    ),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        metric_name="aws-anonymousip",
                        sampled_requests_enabled=True,
                    ),
                ),
            ],
        )

        wafv2.CfnWebACLAssociation(
            self,
            "WebAclAssociation",
            resource_arn=alb.load_balancer_arn,
            web_acl_arn=web_acl.attr_arn,
        )

        waf_logs_bucket = s3.Bucket(
            self,
            "WafLogsBucket",
            encryption=s3.BucketEncryption.S3_MANAGED,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            enforce_ssl=True,
            versioned=True,
            removal_policy=RemovalPolicy.RETAIN,
        )

        firehose_role = iam.Role(
            self,
            "FirehoseRole",
            assumed_by=iam.ServicePrincipal("firehose.amazonaws.com"),
            description="Role for Kinesis Firehose to deliver WAF logs to S3 and write CloudWatch logs",
        )

        waf_logs_bucket.add_to_resource_policy(
            iam.PolicyStatement(
                sid="DenyInsecureTransport",
                effect=iam.Effect.DENY,
                principals=[iam.AnyPrincipal()],
                actions=["s3:*"],
                resources=[waf_logs_bucket.bucket_arn, f"{waf_logs_bucket.bucket_arn}/*"],
                conditions={"Bool": {"aws:SecureTransport": "false"}},
            )
        )

        waf_logs_bucket.grant_read_write(firehose_role)

        log_group = logs.LogGroup(
            self,
            "FirehoseLogGroup",
            retention=logs.RetentionDays.ONE_MONTH,
            removal_policy=RemovalPolicy.DESTROY,
        )

        log_group.grant_write(firehose_role)

        delivery_stream = firehose.CfnDeliveryStream(
            self,
            "WafLogsFirehose",
            delivery_stream_type="DirectPut",
            delivery_stream_encryption_configuration_input=firehose.CfnDeliveryStream.DeliveryStreamEncryptionConfigurationInputProperty(
                key_type="AWS_OWNED_CMK"
            ),
            extended_s3_destination_configuration=firehose.CfnDeliveryStream.ExtendedS3DestinationConfigurationProperty(
                bucket_arn=waf_logs_bucket.bucket_arn,
                role_arn=firehose_role.role_arn,
                buffering_hints=firehose.CfnDeliveryStream.BufferingHintsProperty(
                    interval_in_seconds=300,
                    size_in_m_bs=50,
                ),
                compression_format="GZIP",
                cloud_watch_logging_options=firehose.CfnDeliveryStream.CloudWatchLoggingOptionsProperty(
                    enabled=True,
                    log_group_name=log_group.log_group_name,
                    log_stream_name="WAFLogs",
                ),
                prefix="AWSLogs/WAF/",
                error_output_prefix="AWSLogs/WAF/processing-failed/!{firehose:error-output-type}/!{timestamp:yyyy/MM/dd}/",
            ),
        )

        waf_logging = wafv2.CfnLoggingConfiguration(
            self,
            "WafLogging",
            resource_arn=web_acl.attr_arn,
            log_destination_configs=[delivery_stream.attr_arn],
        )
        waf_logging.node.add_dependency(delivery_stream)
        waf_logging.node.add_dependency(web_acl)

        CfnOutput(self, "AlbDnsName", value=alb.load_balancer_dns_name)
        CfnOutput(self, "WebAclArn", value=web_acl.attr_arn)