from aws_cdk import (
    Stack,
    Duration,
    CfnOutput,
    aws_cloudwatch as cloudwatch,
    aws_cloudwatch_actions as cw_actions,
    aws_sns as sns,
    aws_sns_subscriptions as subscriptions,
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
        on_call_email: str,
        error_rate_threshold_percent: float = 1.0,
        evaluation_periods: int = 2,
        period_minutes: int = 5,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # KMS key for SNS topic encryption (security best practice)
        sns_key = kms.Key(
            self,
            "OnCallTopicKey",
            description=f"KMS key for SNS topic alerting on {api_name} error rate",
            enable_key_rotation=True,
            alias=f"alias/{construct_id}-oncall-sns",
        )

        # SNS topic for paging the on-call engineer
        on_call_topic = sns.Topic(
            self,
            "OnCallTopic",
            display_name=f"OnCall-{api_name}-Alerts",
            topic_name=f"{construct_id}-oncall-pager",
            master_key=sns_key,
        )

        # Enforce TLS-only publishing to the topic
        on_call_topic.add_to_resource_policy(
            statement=__import__(
                "aws_cdk.aws_iam", fromlist=["PolicyStatement"]
            ).PolicyStatement(
                sid="EnforceTLS",
                effect=__import__(
                    "aws_cdk.aws_iam", fromlist=["Effect"]
                ).Effect.DENY,
                principals=[
                    __import__(
                        "aws_cdk.aws_iam", fromlist=["AnyPrincipal"]
                    ).AnyPrincipal()
                ],
                actions=["sns:Publish"],
                resources=[on_call_topic.topic_arn],
                conditions={"Bool": {"aws:SecureTransport": "false"}},
            )
        )

        # Email subscription for the on-call engineer
        on_call_topic.add_subscription(
            subscriptions.EmailSubscription(on_call_email)
        )

        period = Duration.minutes(period_minutes)
        dimensions = {"ApiName": api_name, "Stage": stage_name}

        # API Gateway metrics
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

        # Combined error-rate math expression: ((4XX + 5XX) / Count) * 100
        error_rate_expression = cloudwatch.MathExpression(
            expression="IF(requests > 0, ((errors4xx + errors5xx) / requests) * 100, 0)",
            using_metrics={
                "requests": count_metric,
                "errors4xx": four_xx_metric,
                "errors5xx": five_xx_metric,
            },
            label=f"{api_name} Error Rate (%)",
            period=period,
        )

        error_rate_alarm = cloudwatch.Alarm(
            self,
            "ApiGatewayErrorRateAlarm",
            alarm_name=f"{api_name}-{stage_name}-ErrorRate-GT-{error_rate_threshold_percent}pct",
            alarm_description=(
                f"Pages on-call when {api_name} ({stage_name}) error rate "
                f"exceeds {error_rate_threshold_percent}% over "
                f"{evaluation_periods} periods of {period_minutes} minutes."
            ),
            metric=error_rate_expression,
            threshold=error_rate_threshold_percent,
            evaluation_periods=evaluation_periods,
            datapoints_to_alarm=evaluation_periods,
            comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
            treat_missing_data=cloudwatch.TreatMissingData.NOT_BREACHING,
        )

        # 5XX-specific alarm for fast-path paging on server-side failures
        five_xx_alarm = cloudwatch.Alarm(
            self,
            "ApiGateway5XXAlarm",
            alarm_name=f"{api_name}-{stage_name}-5XXErrors",
            alarm_description=f"Pages on-call on sustained 5XX errors for {api_name} ({stage_name}).",
            metric=five_xx_metric,
            threshold=5,
            evaluation_periods=1,
            comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
            treat_missing_data=cloudwatch.TreatMissingData.NOT_BREACHING,
        )

        sns_action = cw_actions.SnsAction(on_call_topic)
        for alarm in (error_rate_alarm, five_xx_alarm):
            alarm.add_alarm_action(sns_action)
            alarm.add_ok_action(sns_action)
            alarm