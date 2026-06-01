from aws_cdk import (
    Duration,
    Stack,
    aws_cloudwatch as cw,
    aws_cloudwatch_actions as cw_actions,
    aws_sns as sns,
)
from constructs import Construct


class ApiGatewayErrorRateAlarmStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        api_id_param = cdk.CfnParameter(
            self, "ApiId",
            type="String",
            description="API Gateway REST API ID to monitor"
        )

        on_call_topic = sns.Topic(
            self, "OnCallTopic",
            display_name="API-Gateway-OnCall-Paging",
            fifo=False
        )

        errors_metric = cw.Metric(
            namespace="AWS/ApiGateway",
            metric_name="5XXError",
            dimensions_map={"ApiId": api_id_param.value_as_string},
            statistic="Sum",
            period=Duration.minutes(5)
        )

        count_metric = cw.Metric(
            namespace="AWS/ApiGateway",
            metric_name="Count",
            dimensions_map={"ApiId": api_id_param.value_as_string},
            statistic="Sum",
            period=Duration.minutes(5)
        )

        error_rate = cw.MathExpression(
            expression="FILL(errors, 0) / FILL(requests, 1) * 100",
            using_metrics={"errors": errors_metric, "requests": count_metric},
            label="5XXErrorRate",
            period=Duration.minutes(5)
        )

        alarm = cw.Alarm(
            self, "ApiGatewayErrorRateAlarm",
            metric=error_rate,
            threshold=1,
            evaluation_periods=2,
            datapoints_to_alarm=2,
            comparison_operator=cw.ComparisonOperator.GREATER_THAN_THRESHOLD,
            treat_missing_data=cw.TreatMissingData.NOT_BREACHING,
            alarm_description="API Gateway 5XX error rate exceeded 1%"
        )

        alarm.add_alarm_action(cw_actions.SnsAction(on_call_topic))