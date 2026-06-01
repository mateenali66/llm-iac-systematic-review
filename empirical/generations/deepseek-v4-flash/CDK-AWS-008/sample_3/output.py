from aws_cdk import (
    aws_cloudwatch as cloudwatch,
    aws_cloudwatch_actions as cw_actions,
    aws_sns as sns,
    aws_sns_subscriptions as subscriptions,
    aws_apigateway as apigateway,
    aws_iam as iam,
    Duration,
    Stack,
    CfnOutput,
)
from constructs import Construct

class ApiGatewayErrorAlarmStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create SNS topic for paging on-call engineer
        on_call_topic = sns.Topic(
            self,
            "OnCallPagerTopic",
            display_name="API Gateway Error Alarm Topic",
            topic_name="api-gateway-error-alarm",
        )

        # Add email subscription for on-call engineer
        on_call_topic.add_subscription(
            subscriptions.EmailSubscription("oncall@example.com")
        )

        # Reference existing API Gateway (or create a new one)
        # For production, you would typically reference an existing API
        # api = apigateway.RestApi.from_rest_api_id(self, "ExistingApi", "api-id-here")
        
        # Example: Create a sample API for demonstration
        api = apigateway.RestApi(
            self,
            "DemoApi",
            rest_api_name="Demo API",
            description="Demo API for error rate monitoring",
            deploy=True,
            deploy_options=apigateway.StageOptions(
                stage_name="prod",
                metrics_enabled=True,
                logging_level=apigateway.MethodLoggingLevel.INFO,
                data_trace_enabled=False,
                tracing_enabled=True,
            ),
        )

        # Create a sample resource and method
        resource = api.root.add_resource("demo")
        resource.add_method(
            "GET",
            apigateway.MockIntegration(
                integration_responses=[
                    apigateway.IntegrationResponse(
                        status_code="200",
                        response_templates={"application/json": '{"status": "ok"}'},
                    )
                ],
                request_templates={"application/json": '{"statusCode": 200}'},
            ),
            method_responses=[
                apigateway.MethodResponse(status_code="200")
            ],
        )

        # Create CloudWatch metric for API Gateway 5XX errors
        api_error_metric = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="5XXError",
            dimensions_map={
                "ApiName": api.rest_api_name,
                "Stage": "prod",
            },
            statistic="Sum",
            period=Duration.minutes(1),
        )

        # Create CloudWatch metric for API Gateway total requests
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

        # Create math expression for error rate (5XX / total requests)
        error_rate_expression = cloudwatch.MathExpression(
            expression="IF(m2 == 0, 0, (m1 / m2) * 100)",
            using_metrics={
                "m1": api_error_metric,
                "m2": api_request_metric,
            },
            label="Error Rate (%)",
            period=Duration.minutes(1),
        )

        # Create CloudWatch alarm for error rate > 1%
        error_rate_alarm = cloudwatch.Alarm(
            self,
            "ApiGatewayErrorRateAlarm",
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
            cw_actions.SnsAction(on_call_topic)
        )

        # Outputs
        CfnOutput(
            self,
            "AlarmName",
            value=error_rate_alarm.alarm_name,
            description="CloudWatch Alarm Name",
        )
        CfnOutput(
            self,
            "SnsTopicArn",
            value=on_call_topic.topic_arn,
            description="SNS Topic ARN for on-call paging",
        )