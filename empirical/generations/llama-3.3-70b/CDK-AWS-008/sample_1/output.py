import aws_cdk as cdk
from aws_cdk import aws_cloudwatch as cloudwatch
from aws_cdk import aws_cloudwatch_actions as cloudwatch_actions
from aws_cdk import aws_sns as sns
from aws_cdk import aws_sns_subscriptions as sns_subscriptions
from aws_cdk import aws_apigateway as apigateway

class ApiGatewayAlarmStack(cdk.Stack):
    def __init__(self, scope: cdk.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        api = apigateway.RestApi(self, 'api')

        topic = sns.Topic(self, 'topic')

        topic.add_subscription(sns_subscriptions.EmailSubscription('oncall@example.com'))

        error_rate_alarm = cloudwatch.Alarm(
            self, 'error_rate_alarm',
            comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
            threshold=1,
            evaluation_periods=1,
            datapoints_to_alarm=1,
            metric=cloudwatch.Metric(
                namespace='AWS/ApiGateway',
                metric_name='ErrorRate',
                dimensions={
                    'ApiId': api.rest_api_id
                }
            )
        )

        error_rate_alarm.add_alarm_action(
            cloudwatch_actions.SnsAction(topic)
        )

        error_rate_alarm.add_insufficient_data_action(
            cloudwatch_actions.SnsAction(topic)
        )