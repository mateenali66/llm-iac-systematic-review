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

        # Example REST API (replace with your actual API reference)
        api = apigw.RestApi(
            self, "MonitoredApi",
            rest_api_name="Monitored API",
            description="API with CloudWatch monitoring"
        )

        # Create CloudWatch alarm for 5XX errors
        error_rate_alarm = cloudwatch.Alarm(
            self, "HighErrorRateAlarm",
            metric=api.metric(
                "5XXError",
                statistic="Sum",
                period=cloudwatch.Duration.minutes(5)
            ).divide(api.metric(
                "Count",
                statistic="Sum",
                period=cloudwatch.Duration.minutes(5)
            )).multiply(100),
            threshold=1.0,
            evaluation_periods=2,
            datapoints_to_alarm=2,
            comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
            alarm_description="API Gateway error rate exceeded 1%",
            alarm_name="api-gateway-high-error-rate"
        )

        # Add alarm action to notify SNS topic
        error_rate_alarm.add_alarm_action(
            cloudwatch_actions.SnsAction(oncall_topic)
        )

        # Add OK action to notify when alarm recovers
        error_rate_alarm.add_ok_action(
            cloudwatch_actions.SnsAction(oncall_topic)
        )