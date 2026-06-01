from aws_cdk import Stack, aws_cloudwatch as cw, aws_cloudwatch_actions as actions, aws_sns as sns
from constructs import Construct

class ApiGatewayPagingStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, api_id: str, stage: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        topic = sns.Topic(
            self, "OnCallTopic",
            display_name="API-Gateway-OnCall",
            master_key=None
        )

        errors = cw.Metric(
            namespace="AWS/ApiGateway",
            metric_name="5XXError",
            dimensions_map={"ApiId": api_id, "Stage": stage},
            statistic="Sum",
            period=cw.Duration.minutes(5)
        )
        count = cw.Metric(
            namespace="AWS/ApiGateway",
            metric_name="Count",
            dimensions_map={"ApiId": api_id, "Stage": stage},
            statistic="Sum",
            period=cw.Duration.minutes(5)
        )

        error_rate = cw.MathExpression(
            expression="(errors / MAX([count, 1])) * 100",
            using_metrics={"errors": errors, "count": count},
            label="ErrorRatePercent",
            period=cw.Duration.minutes(5)
        )

        alarm = cw.Alarm(
            self, "ApiErrorRateAlarm",
            metric=error_rate,
            threshold=1,
            comparison_operator=cw.ComparisonOperator.GREATER_THAN_THRESHOLD,
            evaluation_periods=3,
            datapoints_to_alarm=2,
            treat_missing_data=cw.TreatMissingData.NOT_BREACHING
        )
        alarm.add_alarm_action(actions.SnsAction(topic))