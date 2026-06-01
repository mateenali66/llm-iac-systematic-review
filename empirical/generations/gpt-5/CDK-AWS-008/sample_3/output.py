from typing import Optional
from constructs import Construct
from aws_cdk import (
    Stack,
    Duration,
    Aws,
    RemovalPolicy,
)
from aws_cdk import aws_cloudwatch as cloudwatch
from aws_cdk import aws_cloudwatch_actions as cloudwatch_actions
from aws_cdk import aws_sns as sns
from aws_cdk import aws_sns_subscriptions as subs
from aws_cdk import aws_kms as kms
from aws_cdk import aws_iam as iam


class ApiGatewayOnCallAlarmsStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        api_identifier: str,
        stage_name: str,
        is_http_api: bool = True,
        oncall_email: Optional[str] = None,
        topic_name: Optional[str] = None,
        alarm_name: Optional[str] = None,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # KMS key for SNS topic encryption
        sns_key = kms.Key(
            self,
            "OnCallSnsKey",
            enable_key_rotation=True,
            removal_policy=RemovalPolicy.RETAIN,
            description="KMS CMK for encrypting on-call SNS topic used by CloudWatch alarms",
        )

        topic = sns.Topic(
            self,
            "OnCallTopic",
            topic_name=topic_name or f"{Aws.STACK_NAME}-oncall-topic",
            master_key=sns_key,
        )

        # Enforce TLS for SNS publish
        topic.add_to_resource_policy(
            iam.PolicyStatement(
                sid="DenyNonTLSPublish",
                effect=iam.Effect.DENY,
                principals=[iam.AnyPrincipal()],
                actions=["SNS:Publish"],
                resources=[topic.topic_arn],
                conditions={"Bool": {"aws:SecureTransport": "false"}},
            )
        )

        # Allow CloudWatch alarms to publish to the topic
        topic.add_to_resource_policy(
            iam.PolicyStatement(
                sid="AllowCloudWatchPublish",
                effect=iam.Effect.ALLOW,
                principals=[iam.ServicePrincipal("cloudwatch.amazonaws.com")],
                actions=["SNS:Publish"],
                resources=[topic.topic_arn],
            )
        )

        if oncall_email:
            topic.add_subscription(subs.EmailSubscription(oncall_email))

        # Metrics for API Gateway
        # For HTTP APIs (v2), dimension is ApiId; for REST APIs (v1), dimension commonly ApiName.
        dim_key = "ApiId" if is_http_api else "ApiName"
        dimensions = {
            dim_key: api_identifier,
            "Stage": stage_name,
        }

        m_4xx = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="4XXError",
            period=Duration.minutes(1),
            statistic="sum",
            dimensions_map=dimensions,
        )
        m_5xx = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="5XXError",
            period=Duration.minutes(1),
            statistic="sum",
            dimensions_map=dimensions,
        )
        m_count = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="Count",
            period=Duration.minutes(1),
            statistic="sum",
            dimensions_map=dimensions,
        )

        # Error rate (%) = 100 * IF(count > 0, (4xx + 5xx) / count, 0)
        error_rate = cloudwatch.MathExpression(
            label=f"{api_identifier}:{stage_name} Error Rate (%)",
            expression="100 * IF(m_count > 0, (m4xx + m5xx) / m_count, 0)",
            using_metrics={
                "m4xx": m_4xx,
                "m5xx": m_5xx,
                "m_count": m_count,
            },
            period=Duration.minutes(1),
        )

        alarm = cloudwatch.Alarm(
            self,
            "ApiGatewayErrorRateAlarm",
            alarm_name=alarm_name
            or f"{Aws.STACK_NAME}-{api_identifier}-{stage_name}-ErrorRate>1pct",
            alarm_description=(
                f"Alarm when API Gateway error rate exceeds 1% "
                f"for {api_identifier} (stage {stage_name})."
            ),
            metric=error_rate,
            threshold=1,
            evaluation_periods=5,
            datapoints_to_alarm=3,
            comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
            treat_missing_data=cloudwatch.TreatMissingData.NOT_BREACHING,
        )

        sns_action = cloudwatch_actions.SnsAction(topic)
        alarm.add_alarm_action(sns_action)
        alarm.add_ok_action(sns_action)