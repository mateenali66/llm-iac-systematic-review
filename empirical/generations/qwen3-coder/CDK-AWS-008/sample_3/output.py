from aws_cdk import (
    Stack,
    aws_apigateway as apigw,
    aws_cloudwatch as cloudwatch,
    aws_cloudwatch_actions as cloudwatch_actions,
    aws_iam as iam,
    aws_sns as sns,
    aws_sns_subscriptions as subscriptions,
)
from constructs import Construct

class ApiGatewayMonitoringStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create SNS topic for on-call notifications
        oncall_topic = sns.Topic(
            self, "ApiGatewayOncallTopic",
            display_name="API Gateway Oncall Notifications"
        )

        # Add security best practice: restrict topic access
        oncall_topic.add_to_resource_policy(
            statement=iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                principals=[iam.ServicePrincipal("cloudwatch.amazonaws.com")],
                actions=["sns:Publish"],
                resources=[oncall_topic.topic_arn]
            )
        )

        # Add subscription - replace with actual on-call engineer email
        oncall_topic.add_subscription(
            subscriptions.EmailSubscription("oncall@example.com")
        )

        # Example REST API Gateway (replace with your actual API reference)
        api = apigw.RestApi(
            self, "MonitoredApi",
            rest_api_name="Monitored-API",
            description="API with CloudWatch monitoring"
        )

        # Create CloudWatch alarm for 5XX errors
        api_5xx_alarm = cloudwatch.Alarm(
            self, "Api5xxErrorRateAlarm",
            metric=api.metric(
                "5XXError",
                statistic="Sum",
                period=cloudwatch.Duration.minutes(5)
            ),
            threshold=1,
            evaluation_periods=2,
            datapoints_to_alarm=2,
            comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
            treat_missing_data=cloudwatch.TreatMissingData.NOT_BREACHING,
            alarm_description="API Gateway 5XX error rate exceeded 1%",
            alarm_name=f"{api.rest_api_name}-5xx-error-rate"
        )

        # Create CloudWatch alarm for 4XX errors
        api_4xx_alarm = cloudwatch.Alarm(
            self, "Api4xxErrorRateAlarm",
            metric=api.metric(
                "4XXError",
                statistic="Sum",
                period=cloudwatch.Duration.minutes(5)
            ),
            threshold=1,
            evaluation_periods=2,
            datapoints_to_alarm=2,
            comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
            treat_missing_data=cloudwatch.TreatMissingData.NOT_BREACHING,
            alarm_description="API Gateway 4XX error rate exceeded 1%",
            alarm_name=f"{api.rest_api_name}-4xx-error-rate"
        )

        # Add actions to alarms
        api_5xx_alarm.add_alarm_action(cloudwatch_actions.SnsAction(oncall_topic))
        api_4xx_alarm.add_alarm_action(cloudwatch_actions.SnsAction(oncall_topic))
        
        # Add OK actions to notify when issue is resolved
        api_5xx_alarm.add_ok_action(cloudwatch_actions.SnsAction(oncall_topic))
        api_4xx_alarm.add_ok_action(cloudwatch_actions.SnsAction(oncall_topic))