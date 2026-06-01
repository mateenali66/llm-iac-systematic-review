from aws_cdk import (
    Stack,
    Duration,
    CfnOutput,
    aws_cloudwatch as cloudwatch,
    aws_cloudwatch_actions as cw_actions,
    aws_sns as sns,
    aws_sns_subscriptions as subs,
    aws_kms as kms,
    aws_iam as iam,
)
from constructs import Construct


class ApiGatewayErrorRateAlarmStack(Stack):
    """
    Creates CloudWatch alarms that page the on-call engineer via SNS
    when API Gateway 4XX or 5XX error rates exceed 1% of total requests.
    """

    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        api_name: str,
        api_stage: str,
        oncall_email: str,
        error_rate_threshold_percent: float = 1.0,
        evaluation_periods: int = 3,
        datapoints_to_alarm: int = 2,
        period_minutes: int = 5,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # --- KMS key for SNS encryption at rest ---
        sns_key = kms.Key(
            self,
            "OncallSnsKey",
            description=f"KMS key for on-call SNS topic ({api_name})",
            enable_key_rotation=True,
            alias=f"alias/{construct_id}-oncall-sns",
        )

        # Allow CloudWatch to use the key to publish to the topic
        sns_key.add_to_resource_policy(
            iam.PolicyStatement(
                sid="AllowCloudWatchAlarmsUseOfKey",
                principals=[iam.ServicePrincipal("cloudwatch.amazonaws.com")],
                actions=[
                    "kms:Decrypt",
                    "kms:GenerateDataKey*",
                ],
                resources=["*"],
            )
        )

        # --- SNS topic for paging ---
        oncall_topic = sns.Topic(
            self,
            "OncallPagingTopic",
            display_name=f"{api_name}-oncall",
            topic_name=f"{construct_id}-oncall-paging",
            master_key=sns_key,
        )

        # Enforce TLS-only transport
        oncall_topic.add_to_resource_policy(
            iam.PolicyStatement(
                sid="DenyInsecureTransport",
                effect=iam.Effect.DENY,
                principals=[iam.AnyPrincipal()],
                actions=["sns:Publish"],
                resources=[oncall_topic.topic_arn],
                conditions={"Bool": {"aws:SecureTransport": "false"}},
            )
        )

        # Email subscription for on-call paging
        oncall_topic.add_subscription(subs.EmailSubscription(oncall_email))

        alarm_action = cw_actions.SnsAction(oncall_topic)

        # --- Common metric properties ---
        period = Duration.minutes(period_minutes)
        dimensions = {"ApiName": api_name, "Stage": api_stage}

        count_metric = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="Count",
            dimensions_map=dimensions,
            period=period,
            statistic="Sum",
        )
        error_4xx_metric = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="4XXError",
            dimensions_map=dimensions,
            period=period,
            statistic="Sum",
        )
        error_5xx_metric = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="5XXError",
            dimensions_map=dimensions,
            period=period,
            statistic="Sum",
        )

        threshold_fraction = error_rate_threshold_percent / 100.0
        min_requests_for_eval = 20  # suppress noisy alarms on low traffic

        # --- 5XX error rate alarm (high severity) ---
        error_5xx_rate = cloudwatch.MathExpression(
            expression="IF(requests > minReq, errors / requests, 0)",
            using_metrics={"errors": error_5xx_metric, "requests": count_metric},
            label="5XXErrorRate",
            period=period,
        )

        alarm_5xx = cloudwatch.Alarm(
            self,
            "ApiGateway5XXErrorRateAlarm",
            alarm_name=f"{api_name}-{api_stage}-5xx-error-rate",
            alarm_description=(
                f"API Gateway 5XX error rate exceeds {error_rate_threshold_percent}% "
                f"for {api_name} ({api_stage}). Pages on-call."
            ),
            metric=cloudwatch.MathExpression(
                expression=f"IF(requests > {min_requests_for_eval}, errors / requests, 0)",
                using_metrics={"errors": error_5xx_metric, "requests": count_metric},
                label="5XXErrorRate",
                period=period,
            ),
            threshold=threshold_fraction,
            evaluation_periods=evaluation_periods,
            datapoints_to_alarm=datapoints_to_alarm,
            comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
            treat_missing_data=cloudwatch.TreatMissingData.NOT_BREACHING,
        )
        alarm_5xx.add_alarm_action(alarm_action)
        alarm_5xx.add_ok_action(alarm_action)
        alarm_5xx.add_insufficient_data_action(alarm_action)

        # --- 4XX error rate alarm (lower severity, same topic) ---
        alarm_4xx = cloudwatch.Alarm(
            self,
            "ApiGateway4XXErrorRateAlarm",
            alarm_name=f"{