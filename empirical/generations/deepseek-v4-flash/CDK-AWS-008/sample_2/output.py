from aws_cdk import (
    aws_cloudwatch as cloudwatch,
    aws_cloudwatch_actions as cw_actions,
    aws_sns as sns,
    aws_sns_subscriptions as subscriptions,
    aws_apigateway as apigateway,
    aws_iam as iam,
    Duration,
    Stack,
    RemovalPolicy,
)
from constructs import Construct

class ApiGatewayErrorAlarmStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create SNS topic for paging on-call engineer
        on_call_topic = sns.Topic(
            self,
            "OnCallPagerTopic",
            display_name="API Gateway Error Rate Alarm Topic",
            topic_name="api-gateway-error-alarm",
        )

        # Add email subscription for on-call engineer
        # Replace with actual on-call email address
        on_call_topic.add_subscription(
            subscriptions.EmailSubscription("oncall@example.com")
        )

        # Create a sample API Gateway REST API for demonstration
        # In production, reference an existing API or pass as parameter
        api = apigateway.RestApi(
            self,
            "SampleApi",
            rest_api_name="Sample API",
            description="Sample API for monitoring",
            deploy=True,
            deploy_options=apigateway.StageOptions(
                stage_name="prod",
                throttling_rate_limit=1000,
                throttling_burst_limit=500,
            ),
            default_cors_preflight_options=apigateway.CorsOptions(
                allow_origins=apigateway.Cors.ALL_ORIGINS,
                allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            ),
        )

        # Add a sample resource and method
        resource = api.root.add_resource("items")
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
        error_metric = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="5XXError",
            dimensions_map={
                "ApiName": api.rest_api_name,
                "Stage": "prod",
            },
            statistic="Sum",
            period=Duration.minutes(1),
        )

        # Create CloudWatch metric for total requests
        total_metric = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="Count",
            dimensions_map={
                "ApiName": api.rest_api_name,
                "Stage": "prod",
            },
            statistic="Sum",
            period=Duration.minutes(1),
        )

        # Create math expression for error rate percentage
        error_rate_metric = cloudwatch.MathExpression(
            expression="(errors / total) * 100",
            using_metrics={
                "errors": error_metric,
                "total": total_metric,
            },
            period=Duration.minutes(1),
            label="Error Rate (%)",
        )

        # Create CloudWatch alarm for error rate > 1%
        error_rate_alarm = cloudwatch.Alarm(
            self,
            "ApiGatewayErrorRateAlarm",
            alarm_name="api-gateway-error-rate-high",
            alarm_description="API Gateway error rate exceeds 1% threshold",
            metric=error_rate_metric,
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

        # Add OK action to notify when alarm clears
        error_rate_alarm.add_ok_action(
            cw_actions.SnsAction(on_call_topic)
        )

        # Output the SNS topic ARN and API Gateway URL
        self.export_value(
            on_call_topic.topic_arn,
            export_name=f"{self.stack_name}-OnCallTopicArn",
        )
        self.export_value(
            api.url,
            export_name=f"{self.stack_name}-ApiUrl",
        )