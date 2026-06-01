from aws_cdk import (
    Stack,
    Duration,
    RemovalPolicy,
    CfnOutput,
    aws_apigateway as apigateway,
    aws_cloudwatch as cloudwatch,
    aws_cloudwatch_actions as cw_actions,
    aws_sns as sns,
    aws_sns_subscriptions as subscriptions,
    aws_kms as kms,
    aws_iam as iam
)
from constructs import Construct

class ApiGatewayAlarmStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, on_call_email: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create a KMS key for SNS Topic encryption for enhanced security
        kms_key = kms.Key(
            self, "SnsKmsKey",
            description="KMS key for encrypting the on-call SNS topic",
            enable_key_rotation=True,
            removal_policy=RemovalPolicy.DESTROY, # Use RETAIN in a real production environment
            alias="alias/oncall/SnsKey"
        )

        # Create an SNS topic for on-call notifications
        on_call_topic = sns.Topic(
            self, "OnCallSnsTopic",
            display_name="On-Call Paging Topic",
            topic_name="api-gateway-high-error-rate-alarm-topic",
            master_key=kms_key
        )

        # Grant CloudWatch permissions to publish to the SNS topic
        on_call_topic.add_to_resource_policy(
            iam.PolicyStatement(
                actions=["sns:Publish"],
                resources=[on_call_topic.topic_arn],
                principals=[iam.ServicePrincipal("cloudwatch.amazonaws.com")],
                effect=iam.Effect.ALLOW
            )
        )

        # Subscribe the on-call engineer's email to the topic
        on_call_topic.add_subscription(
            subscriptions.EmailSubscription(on_call_email)
        )

        # Create a sample API Gateway to monitor
        api = apigateway.RestApi(
            self, "MonitoredApi",
            rest_api_name="MonitoredServiceApi",
            description="This API is monitored for high error rates.",
            deploy_options=apigateway.StageOptions(
                metrics_enabled=True,
                logging_level=apigateway.MethodLoggingLevel.ERROR,
                tracing_enabled=True,
                stage_name="prod"
            ),
            cloud_watch_role=True
        )

        # Add a sample endpoint
        api.root.add_method("GET", apigateway.MockIntegration(
            integration_responses=[{
                "statusCode": "200"
            }],
            passthrough_behavior=apigateway.PassthroughBehavior.NEVER,
            request_templates={"application/json": '{"statusCode": 200}'}
        ))

        # Define the metric for 5XX errors
        five_xx_errors_metric = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="5XXError",
            dimensions_map={
                "ApiName": api.rest_api_name,
                "Stage": api.deployment_stage.stage_name
            },
            period=Duration.minutes(1),
            statistic="Sum"
        )

        # Define the metric for total requests
        total_requests_metric = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="Count",
            dimensions_map={
                "ApiName