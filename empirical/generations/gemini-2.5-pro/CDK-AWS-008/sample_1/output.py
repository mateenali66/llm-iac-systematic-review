import aws_cdk as cdk
from aws_cdk import (
    Stack,
    Duration,
    aws_sns as sns,
    aws_sns_subscriptions as sns_subscriptions,
    aws_apigateway as apigateway,
    aws_cloudwatch as cloudwatch,
    aws_cloudwatch_actions as cw_actions,
)
from constructs import Construct

class ApiGatewayAlarmsStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # SNS Topic for on-call notifications
        on_call_topic = sns.Topic(
            self, "OnCallSnsTopic",
            display_name="API Gateway High Error Rate Alerts",
            topic_name="api-gateway-on-call-alerts"
        )

        # Example subscription - replace with your actual paging service endpoint
        on_call_topic.add_subscription(
            sns_subscriptions.EmailSubscription("on-call-engineer@example.com")
        )

        # A sample API Gateway to monitor
        # In a real-world scenario, you would import an existing API
        api = apigateway.RestApi(
            self, "MonitoredApi",
            rest_api_name="MyMonitoredServiceApi",
            description="This API is monitored for high error rates.",
            deploy_options=apigateway.StageOptions(
                stage_name="prod",
                metrics_enabled=True,
                logging_level=apigateway.MethodLoggingLevel.ERROR,
                data_trace_enabled=True
            )
        )

        # Add a mock integration for demonstration purposes
        api.root.add_method(
            "GET",
            apigateway.MockIntegration(
                integration_responses=[
                    apigateway.IntegrationResponse(
                        status_code="200",
                        response_templates={"application/json": "{\"status\": \"ok\"}"}
                    )
                ],
                passthrough_behavior=apigateway.PassthroughBehavior.NEVER,
                request_templates={"application/json": "{\"statusCode\": 200}"}
            ),
            method_responses=[
                apigateway.MethodResponse(status_code="200")
            ]
        )

        # Define CloudWatch metrics for the API Gateway
        api_dimensions = {
            "ApiName": api.rest_api_name,
            "Stage": api.deployment_stage.stage_name
        }

        # Metric for 5XX server-side errors
        five_xx_errors = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="5XXError",
            dimensions_map=api_dimensions,
            statistic="Sum",
            period=Duration.minutes(5)
        )

        # Metric for the total number of requests
        total_requests = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="Count",
            dimensions_map=api_dimensions,
            statistic="Sum",
            period=Duration.minutes(5)
        )

        # CloudWatch Math Expression to calculate the error rate percentage
        error_rate_expression = cloudwatch.MathExpression(
            expression="(m1 / m2) * 100",
            using_metrics={
                "m1": five_xx_errors,
                "m2": total_requests
            },
            label="ApiGatewayErrorRatePercentage",
            period=Duration.minutes(5)
        )

        # CloudWatch Alarm for the high error rate
        high_error_rate_alarm = cloudwatch.Alarm(
            self, "HighErrorRateAlarm",
            alarm_name="