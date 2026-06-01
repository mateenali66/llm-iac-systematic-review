from aws_cdk import (
    Stack,
    Duration,
    RemovalPolicy,
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

        # Networking
        vpc = ec2.Vpc(
            self,
            "Vpc",
            max_azs=2,
            nat_gateways=1,
        )

        # Security Group for ALB
        alb_sg = ec2.SecurityGroup(
            self,
            "AlbSecurityGroup",
            vpc=vpc,
            description="Security group for ALB",
            allow_all_outbound=True,
        )
        alb_sg.add_ingress_rule(ec2.Peer.any_ipv4(), ec2.Port.tcp(80), "Allow HTTP from anywhere")
        alb_sg.add_ingress_rule(ec2.Peer.any_ipv6(), ec2.Port.tcp(80), "Allow HTTP from anywhere (IPv6)")

        # Application Load Balancer
        alb = elbv2.ApplicationLoadBalancer(
            self,
            "Alb",
            vpc=vpc,
            internet_facing=True,
            security_group=alb_sg,
            deletion_protection=True,
        )

        # Listener with fixed response (no target required)
        listener = alb.add_listener(
            "HttpListener",
            port=80,
            open=True,
            default_action=elbv2.ListenerAction.fixed_response(
                status_code=200,
                content_type="text/plain",
                message_body="OK",
            ),
        )

        # S3 bucket for WAF logs (delivered via Firehose)
        waf_logs_bucket = s3.Bucket(
            self,
            "WafLogsBucket",
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            encryption=s3.BucketEncryption.S3_MANAGED,
            enforce_ssl=True,
            versioned=True,
            removal_policy=RemovalPolicy.RETAIN,
            auto_delete_objects=False,
        )

        # CloudWatch Logs for Firehose diagnostics
        firehose_log_group = logs.LogGroup(
            self,
            "FirehoseLogGroup",
            retention=logs.RetentionDays.ONE_MONTH,
            removal_policy=RemovalPolicy.DESTROY,
        )
        firehose_log_stream = logs.LogStream(
            self,
            "FirehoseLogStream",
            log_group=firehose_log_group,
            log_stream_name="firehose/waf-logs",
            removal_policy=RemovalPolicy.DESTROY,
        )

        # IAM Role for Firehose to write to S3
        firehose_role = iam.Role(
            self,
            "FirehoseRole",
            assumed_by=iam.ServicePrincipal("firehose.amazonaws.com"),
            description="Role for Kinesis Data Firehose to deliver WAF logs to S3",
        )
        firehose_role.add_to_policy(
            iam.PolicyStatement(
                actions=[
                    "s3:AbortMultipartUpload",
                    "s3:GetBucketLocation",
                    "s3:GetObject",
                    "s3:ListBucket",
                    "s3:ListBucketMultipartUploads",
                    "s3:PutObject",
                ],
                resources=[
                    waf_logs_bucket.bucket_arn,
                    f"{waf_logs_bucket.bucket_arn}/*",
                ],
            )
        )

        # Firehose Delivery Stream for WAF logs
        firehose_stream = firehose.CfnDeliveryStream(
            self,
            "WafLogsDeliveryStream",
            delivery_stream_type="DirectPut",
            s3_destination_configuration=firehose.CfnDeliveryStream.S3DestinationConfigurationProperty(
                bucket_arn=waf_logs_bucket.bucket_arn,
                role_arn=firehose_role.role_arn,
                buffering_hints=firehose.CfnDeliveryStream.BufferingHintsProperty(
                    interval_in_seconds=300,
                    size_in_m_bs=5,
                ),
                cloud_watch_logging_options=firehose.CfnDeliveryStream.CloudWatchLoggingOptionsProperty(
                    enabled=True,
                    log_group_name=firehose_log_group.log_group_name,
                    log_stream_name=firehose_log_stream.log_stream_name,
                ),
                compression_format="GZIP",
            ),
        )

        # WAFv2 Web ACL with AWS Managed Rule Sets
        web_acl = wafv2.CfnWebACL(
            self,
            "AlbWebAcl",
            default_action=wafv2.CfnWebACL.DefaultActionProperty(allow={}),
            scope="REGIONAL",
            visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                cloud_watch_metrics_enabled=True,
                sampled_requests_enabled=True,
                metric_name="AlbWebAcl",
            ),
            rules=[
                wafv2.CfnWebACL.RuleProperty(
                    name="RateLimitIP",
                    priority=0,
                    statement=wafv2.CfnWebACL.StatementProperty(
                        rate_based_statement=wafv2.CfnWebACL.RateBasedStatementProperty(
                            limit=2000,
                            aggregate_key_type="IP",
                        )
                    ),
                    action=wafv2.CfnWebACL.RuleActionProperty(block={}),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        sampled_requests_enabled=True,
                        metric_name="RateLimitIP",
                    ),
                ),
                wafv2.CfnWebACL.RuleProperty(
                    name="AWSManagedRulesCommonRuleSet",
                    priority=1,
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesCommonRuleSet",
                        )
                    ),
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        sampled_requests_enabled=True,
                        metric_name="AWSManagedRulesCommonRuleSet",
                    ),
                ),
                wafv2.CfnWebACL.RuleProperty(
                    name="AWSManagedRulesKnownBadInputsRuleSet",
                    priority=2,
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesKnownBadInputsRuleSet",
                        )
                    ),
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        sampled_requests_enabled=True,
                        metric_name="AWSManagedRulesKnownBadInputsRuleSet",
                    ),
                ),
                wafv2.CfnWebACL.RuleProperty(
                    name="AWSManagedRulesAmazonIpReputationList",
                    priority=3,
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesAmazonIpReputationList",
                        )
                    ),
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        sampled_requests_enabled=True,
                        metric_name="AWSManagedRulesAmazonIpReputationList",
                    ),
                ),
                wafv2.CfnWebACL.RuleProperty(
                    name="AWSManagedRulesAnonymousIpList",
                    priority=4,
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesAnonymousIpList",
                        )
                    ),
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        sampled_requests_enabled=True,
                        metric_name="AWSManagedRulesAnonymousIpList",
                    ),
                ),
                wafv2.CfnWebACL.RuleProperty(
                    name="AWSManagedRulesSQLiRuleSet",
                    priority=5,
                    statement=wafv2.CfnWebACL.StatementProperty(
                        managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                            vendor_name="AWS",
                            name="AWSManagedRulesSQLiRuleSet",
                        )
                    ),
                    override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
                    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                        cloud_watch_metrics_enabled=True,
                        sampled_requests_enabled=True,
                        metric_name="AWSManagedRulesSQLiRuleSet",
                    ),
                ),
            ],
        )

        # Associate WAF Web ACL with ALB
        wafv2.CfnWebACLAssociation(
            self,
            "AlbWafAssociation",
            resource_arn=alb.load_balancer_arn,
            web_acl_arn=web_acl.attr_arn,
        )

        # Enable WAF logging to Firehose
        waf_logs = wafv2.CfnLoggingConfiguration(
            self,
            "WafLoggingConfiguration",
            resource_arn=web_acl.attr_arn,
            log_destination_configs=[firehose_stream.attr_arn],
        )
        waf_logs.node.add_dependency(firehose_stream)
        waf_logs.node.add_dependency(web_acl)