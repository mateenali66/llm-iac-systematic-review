from aws_cdk import (
    Stack,
    Duration,
    CfnParameter,
    aws_apigateway as apigateway,
    aws_sns as sns,
    aws_sns_subscriptions as subs,
    aws_cloudwatch as cloudwatch,
    aws_cloudwatch_actions as cw_actions,
)
from constructs import Construct

class ApiGatewayAlarmsStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        on_call_email = CfnParameter(self, "OnCallEmail",
            type="String",
            description="The email address for the on-call engineer to receive alerts.",
            min_length=5
        )

        # This creates a sample API Gateway to monitor.
        # In a real-world scenario, you would likely look up an existing API:
        # api = apigateway.RestApi.from_rest_api_attributes(self, "ImportedApi", ...)
        api = apigateway.RestApi(self, "MonitoredApi",
            rest_api_name="MyMonitoredServiceApi",
            description="This API is monitored for high error rates.",
            deploy_options=apigateway.StageOptions(
                stage_name="prod",
                metrics_enabled=True,
                logging_level=apigateway.MethodLoggingLevel.ERROR,
                data_trace_enabled=True
            )
        )

        # Add a dummy endpoint to the API
        api.root.add_method("GET", apigateway.MockIntegration(
            integration_responses=[{
                'statusCode': '200',
                'response_parameters': {
                    'method.response.header.Content-Type': "'application/json'",
                },
                'response_templates': {
                    'application/json': '{"status": "ok"}'
                }
            }],
            passthrough_behavior=apigateway.PassthroughBehavior.NEVER,
            request_templates={
                "application/json": '{"statusCode": 200}'
            }
        ),
        method_responses=[{
            'statusCode': '200',
            'response_parameters': {
                'method.response.header.Content-Type': True,
            }
        }])

        # SNS Topic for paging the on-call engineer
        alarm_topic = sns.Topic(self, "ApiAlarmTopic",
            display_name="APIGateway High Error Rate Alarm",
            topic_name="api-gateway-high-error-rate-alarm"
        )

        # Subscribe the on-call email to the topic