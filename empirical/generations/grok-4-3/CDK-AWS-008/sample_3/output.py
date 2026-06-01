from aws_cdk import (
    Stack,
    Duration,
    aws_sns as sns,
    aws_cloudwatch as cw,
    aws_cloudwatch_actions as cw_actions,
)
from constructs import Construct


class ApiGatewayErrorRateAlarmStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        oncall_topic = sns.Topic(
            self,
            "OnCallTopic",
            display_name="API Gateway On-Call Paging",
            fifo=False,
        )

        api_name = "MyApi"
        stage = "prod"

        error_count_metric = cw.Metric(
            namespace="AWS/ApiGateway",
            metric_name="5XXError",
            dimensions_map={"ApiName": api_name, "Stage": stage},
            statistic="Sum",
            period=Duration.minutes(5),
        )

        request_count_metric = cw.Metric(
            namespace="AWS/ApiGateway",
            metric_name="Count",
            dimensions_map={"ApiName": api_name, "Stage": stage},
            statistic="Sum",
            period=Duration.minutes(5),
        )

        error_rate_expression = cw.MathExpression(
            expression="IF(requests > 0, (errors / requests) * 100, 0)",
            using_metrics={"errors": error_count_metric, "requests": request_count_metric},
            label="ErrorRatePercent",
            period=Duration.minutes(5),
        )

        alarm = cw.Alarm(
            self,
            "ApiGatewayErrorRateAlarm",
            metric=error_rate_expression,
            threshold=1,
            comparison_operator=cw.ComparisonOperator.GREATER_THAN_THRESHOLD,
            evaluation_periods=2,
            datapoints_to_alarm=2,
            treat_missing_data=cw.TreatMissingData.NOT_BREACHING,
            alarm_description="API Gateway 5XX error rate exceeded 1% - paging on-call engineer",
        )

        alarm.add_alarm_action(cw_actions.SnsAction(oncall_topic))