from aws_cdk import (
    Stack,
    Duration,
    CfnOutput,
    aws_cloudwatch as cloudwatch,
    aws_cloudwatch_actions as cw_actions,
    aws_sns as sns,
    aws_sns_subscriptions as sns_subs,
    aws_kms as kms,
)
from constructs import Construct


class ApiGatewayErrorRateAlarmStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        api_name: str,
        stage_name: str = "prod",
        oncall_email: str,
        error_rate_threshold_percent: float = 1.0,
        evaluation_periods: int = 2,
        datapoints_to_alarm: int = 2,
        period_minutes: int = 5,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # KMS key for SNS topic encryption at rest
        topic_key = kms.Key(
            self,
            "OncallTopicKey",
            description=f"KMS key for on-call SNS topic ({api_name})",
            enable_key_rotation=True,
            alias=f"alias/{construct_id}-oncall-sns",
        )

        # SNS topic for paging on-call engineers
        oncall_topic = sns.Topic(
            self,
            "OncallTopic",
            display_name=f"{api_name} On-Call Pager",
            topic_name=f"{api_name}-{stage_name}-oncall",
            master_key=topic_key,
        )

        # Enforce TLS in transit
        oncall_topic.add_to_resource_policy(
            __import__("aws_cdk").aws_iam.PolicyStatement(
                sid="DenyInsecureTransport",
                actions=["sns:Publish"],
                effect=__import__("aws_cdk").aws_iam.Effect.DENY,
                principals=[__import__("aws_cdk").aws_iam.AnyPrincipal()],
                resources=[oncall_topic.topic_arn],
                conditions={"Bool": {"aws:SecureTransport": "false"}},
            )
        )

        # Subscribe on-call email (replace with PagerDuty/Opsgenie HTTPS endpoint in real prod)
        oncall_topic.add_subscription(sns_subs.EmailSubscription(oncall_email))

        period = Duration.minutes(period_minutes)

        # API Gateway metrics (REST API). Use ApiName + Stage dimensions.
        dimensions = {"ApiName": api_name, "Stage": stage_name}

        count_metric = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="Count",
            dimensions_map=dimensions,
            statistic="Sum",
            period=period,
        )
        four_xx_metric = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="4XXError",
            dimensions_map=dimensions,
            statistic="Sum",
            period=period,
        )
        five_xx_metric = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="5XXError",
            dimensions_map=dimensions,
            statistic="Sum",
            period=period,
        )

        # Combined error rate (%) = (4XX + 5XX) / Count * 100, guarded against zero traffic
        error_rate_expression = cloudwatch.MathExpression(
            expression="IF(requests > 0, (errors4xx + errors5xx) / requests * 100, 0)",
            using_metrics={
                "requests": count_metric,
                "errors4xx": four_xx_metric,
                "errors5xx": five_xx_metric,
            },
            label="API Error Rate (%)",
            period=period,
        )

        combined_error_rate_alarm = cloudwatch.Alarm(
            self,
            "ApiErrorRateAlarm",
            alarm_name=f"{api_name}-{stage_name}-error-rate-gt-{error_rate_threshold_percent}pct",
            alarm_description=(
                f"Pages on-call when {api_name} ({stage_name}) total error rate "
                f"(4XX+5XX) exceeds {error_rate_threshold_percent}% over "
                f"{evaluation_periods} x {period_minutes}m windows."
            ),
            metric=error_rate_expression,
            threshold=error_rate_threshold_percent,
            evaluation_periods=evaluation_periods,
            datapoints_to_alarm=datapoints_to_alarm,
            comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
            treat_missing_data=cloudwatch.TreatMissingData.NOT_BREACHING,
            actions_enabled=True,
        )
        combined_error_rate_alarm.add_alarm_action(cw_actions.SnsAction(oncall_topic))
        combined_error_rate_alarm.add_ok_action(cw_actions.SnsAction(oncall_topic))
        combined_error_rate_alarm.add_insufficient_data_action(
            cw_actions.SnsAction(oncall_topic)
        )

        # Dedicated 5XX error rate alarm (server-side reliability signal)
        five_xx_rate_expression = cloudwatch.MathExpression(
            expression="IF(requests > 0, errors5xx / requests * 100, 0)",
            using_metrics={"requests": count_metric, "errors5xx": five_xx_metric},
            label="API 5XX Error Rate (%)",
            period=period,
        )

        five_xx_alarm = cloudwatch.Alarm(
            self,
            "Api5xxErrorRateAlarm",
            alarm_name=f"{api_name}-{stage_name}-5xx-rate-gt-{error_rate_threshold_percent}pct",