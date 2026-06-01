from aws_cdk import (
    App,
    Stack,
    Duration,
    Environment,
    RemovalPolicy,
    aws_kms as kms,
    aws_sns as sns,
    aws_iam as iam,
    aws_cloudwatch as cw,
    aws_cloudwatch_actions as cw_actions,
)
from constructs import Construct
import os


class ApiGatewayErrorRateAlarmStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        key = kms.Key(
            self,
            "OnCallSnsKey",
            enable_key_rotation=True,
            alias="alias/oncall-sns",
            removal_policy=RemovalPolicy.RETAIN,
        )

        topic = sns.Topic(
            self,
            "OnCallTopic",
            display_name="On-Call Paging",
            master_key=key,
        )

        topic.add_to_resource_policy(
            iam.PolicyStatement(
                effect=iam.Effect.DENY,
                principals=[iam.AnyPrincipal()],
                actions=["sns:Publish"],
                resources=[topic.topic_arn],
                conditions={"Bool": {"aws:SecureTransport": "false"}},
            )
        )

        rest_4xx = cw.Metric(
            namespace="AWS/ApiGateway",
            metric_name="4XXError",
            statistic="sum",
            period=Duration.minutes(1),
        )
        rest_5xx = cw.Metric(
            namespace="AWS/ApiGateway",
            metric_name="5XXError",
            statistic="sum",
            period=Duration.minutes(1),
        )
        rest_count = cw.Metric(
            namespace="AWS/ApiGateway",
            metric_name="Count",
            statistic="sum",
            period=Duration.minutes(1),
        )

        http_4xx = cw.Metric(
            namespace="AWS/ApiGateway",
            metric_name="4xx",
            statistic="sum",
            period=Duration.minutes(1),
        )
        http_5xx = cw.Metric(
            namespace="AWS/ApiGateway",
            metric_name="5xx",
            statistic="sum",
            period=Duration.minutes(1),
        )
        http_count = cw.Metric(
            namespace="AWS/ApiGateway",
            metric_name="RequestCount",
            statistic="sum",
            period=Duration.minutes(1),
        )

        total_errors = cw.MathExpression(
            expression="r4 + r5 + h4 + h5",
            using_metrics={"r4": rest_4xx, "r5": rest_5xx, "h4": http_4xx, "h5": http_5xx},
            period=Duration.minutes(1),
        )
        total_requests = cw.MathExpression(
            expression="rc + hc",
            using_metrics={"rc": rest_count, "hc": http_count},
            period=Duration.minutes(1),
        )

        overall_error_rate_pct = cw.MathExpression(
            expression="IF(req > 0, 100 * err / req, 0)",
            using_metrics={"err": total_errors, "req": total_requests},
            period=Duration.minutes(1),
        )

        server_errors = cw.MathExpression(
            expression="r5 + h5",
            using_metrics={"r5": rest_5xx, "h5": http_5xx},
            period=Duration.minutes(1),
        )
        server_error_rate_pct = cw.MathExpression(
            expression="IF(req > 0, 100 * serr / req, 0)",
            using_metrics={"serr": server_errors, "req": total_requests},
            period=Duration.minutes(1),
        )

        sns_action = cw_actions.SnsAction(topic)

        overall_alarm = cw.Alarm(
            self,
            "ApiGatewayOverallErrorRateAlarm",
            alarm_name=f"{Stack.of(self).stack_name}-ApiGw-OverallErrorRate>1pct",
            metric=overall_error_rate_pct,
            threshold=1,
            evaluation_periods=5,
            datapoints_to_alarm=3,
            treat_missing_data=cw.TreatMissingData.NOT_BREACHING,
            comparison_operator=cw.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
            alarm_description="Overall API Gateway error rate (4xx+5xx across REST and HTTP APIs) exceeded 1% over the last 5 minutes.",
        )
        overall_alarm.add_alarm_action(sns_action)
        overall_alarm.add_ok_action(sns_action)

        server_alarm = cw.Alarm(
            self,
            "ApiGateway5xxErrorRateAlarm",
            alarm_name=f"{Stack.of(self).stack_name}-ApiGw-5xxErrorRate>1pct",
            metric=server_error_rate_pct,
            threshold=1,
            evaluation_periods=5,
            datapoints_to_alarm=3,
            treat_missing_data=cw.TreatMissingData.NOT_BREACHING,
            comparison_operator=cw.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
            alarm_description="API Gateway 5xx error rate exceeded 1% over the last 5 minutes.",
        )
        server_alarm.add_alarm_action(sns_action)
        server_alarm.add_ok_action(sns_action)


app = App()
ApiGatewayErrorRateAlarmStack(
    app,
    "ApiGatewayErrorRateAlarms",
    env=Environment(account=os.getenv("CDK_DEFAULT_ACCOUNT"), region=os.getenv("CDK_DEFAULT_REGION")),
)
app.synth()