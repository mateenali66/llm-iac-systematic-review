from aws_cdk import (
    aws_cloudwatch as cloudwatch,
    aws_sns as sns,
    aws_sns_subscriptions as subscriptions,
    aws_apigateway as apigateway,
    aws_cloudwatch_actions as cw_actions,
    aws_kms as kms,
    Stack,
    Duration,
    RemovalPolicy,
)
from constructs import Construct

class ApiGatewayErrorAlarmStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create a KMS key for SNS encryption
        sns_key = kms.Key(
            self,
            "SnsEncryptionKey",
            enable_key_rotation=True,
            removal_policy=RemovalPolicy.DESTROY,
            description="KMS key for SNS topic encryption",
        )

        # Create SNS topic for paging on-call engineer
        pager_topic = sns.Topic(
            self,
            "OnCallPagerTopic",
            display_name="API Gateway Error Alarm Topic",
            topic_name="api-gateway-error-alarm",
            master_key=sns_key,
        )

        # Add email subscription for on-call engineer
        # Replace with actual on-call email address
        pager_topic.add_subscription(
            subscriptions.EmailSubscription("oncall@example.com")
        )

        # Reference existing API Gateway (or create a placeholder)
        # In production, you would reference your actual API
        api = apigateway.RestApi.from_rest_api_attributes(
            self,
            "ExistingApi",
            rest_api_id="your-api-id",
            root_resource_id="your-root-resource-id",
        )

        # Create metric for API Gateway 5XX errors
        api_error_metric = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="5XXError",
            dimensions_map={
                "ApiName": api.rest_api_name,
                "Stage": "prod",  # Adjust stage as needed
            },
            statistic="Sum",
            period=Duration.minutes(1),
        )

        # Create metric for total API requests
        api_request_metric = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="Count",
            dimensions_map={
                "ApiName": api.rest_api_name,
                "Stage": "prod",
            },
            statistic="Sum",
            period=Duration.minutes(1),
        )

        # Create math expression for error rate
        error_rate_expression = cloudwatch.MathExpression(
            expression="(errors / requests) * 100",
            using_metrics={
                "errors": api_error_metric,
                "requests": api_request_metric,
            },
            period=Duration.minutes(1),
            label="ErrorRate",
        )

        # Create CloudWatch alarm for error rate > 1%
        error_rate_alarm = cloudwatch.Alarm(
            self,
            "ApiErrorRateAlarm",
            alarm_name="api-gateway-error-rate-high",
            alarm_description="API Gateway error rate exceeds 1%",
            metric=error_rate_expression,
            threshold=1,
            evaluation_periods=2,
            datapoints_to_alarm=2,
            comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
            treat_missing_data=cloudwatch.TreatMissingData.NOT_BREACHING,
        )

        # Add SNS action to alarm
        error_rate_alarm.add_alarm_action(
            cw_actions.SnsAction(pager_topic)
        )

        # Add OK action to notify when resolved
        error_rate_alarm.add_ok_action(
            cw_actions.SnsAction(pager_topic)
        )