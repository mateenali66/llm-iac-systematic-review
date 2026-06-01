from aws_cdk import (
    Stack,
    Duration,
    CfnParameter,
    CfnCondition,
    Fn,
    CfnOutput,
    RemovalPolicy,
    aws_cloudwatch as cloudwatch,
    aws_cloudwatch_actions as cloudwatch_actions,
    aws_sns as sns,
    aws_kms as kms,
    aws_iam as iam,
)
from constructs import Construct


class ApiGatewayOnCallAlarmStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        api_name_param = CfnParameter(
            self,
            "ApiName",
            type="String",
            description="API Gateway REST API name for which to monitor error rate.",
        )

        stage_name_param = CfnParameter(
            self,
            "StageName",
            type="String",
            description="API Gateway stage name for which to monitor error rate (e.g., prod).",
        )

        oncall_email_param = CfnParameter(
            self,
            "OnCallEmail",
            type="String",
            default="",
            description="Optional: Email address to subscribe to the on-call paging SNS topic.",
        )

        has_oncall_email = CfnCondition(
            self,
            "HasOnCallEmail",
            expression=Fn.condition_not(Fn.condition_equals(oncall_email_param.value_as_string, "")),
        )

        sns_key = kms.Key(
            self,
            "OnCallSnsKey",
            enable_key_rotation=True,
            alias="alias/oncall-sns-topic",
            description="CMK for encrypting on-call SNS topic messages",
            removal_policy=RemovalPolicy.RETAIN,
        )

        oncall_topic = sns.Topic(
            self,
            "OnCallTopic",
            master_key=sns_key,
            display_name="On-Call Paging",
        )

        oncall_topic.add_to_resource_policy(
            iam.PolicyStatement(
                sid="EnforceTLS",
                effect=iam.Effect.DENY,
                principals=[iam.AnyPrincipal()],
                actions=["sns:*"],
                resources=[oncall_topic.topic_arn],
                conditions={"Bool": {"aws:SecureTransport": "false"}},
            )
        )

        email_subscription = sns.CfnSubscription(
            self,
            "OnCallEmailSubscription",
            topic_arn=oncall_topic.topic_arn,
            protocol="email",
            endpoint=oncall_email_param.value_as_string,
        )
        email_subscription.cfn_options.condition = has_oncall_email

        period = Duration.minutes(5)

        m_4xx = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="4XXError",
            dimensions_map={
                "ApiName": api_name_param.value_as_string,
                "Stage": stage_name_param.value_as_string,
            },
            statistic="sum",
            period=period,
        )

        m_5xx = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="5XXError",
            dimensions_map={
                "ApiName": api_name_param.value_as_string,
                "Stage": stage_name_param.value_as_string,
            },
            statistic="sum",
            period=period,
        )

        m_count = cloudwatch.Metric(
            namespace="AWS/ApiGateway",
            metric_name="Count",
            dimensions_map={
                "ApiName": api_name_param.value_as_string,
                "Stage": stage_name_param.value_as_string,
            },
            statistic="sum",
            period=period,
        )

        error_rate_expr = cloudwatch.MathExpression(
            expression="((m4 + m5) / mcount) * 100",
            using_metrics={
                "m4": m_4xx,
                "m5": m_5xx,
                "mcount": m_count,
            },
            period=period,
        )

        error_rate_alarm = cloudwatch.Alarm(
            self,
            "ApiGatewayErrorRateAlarm",
            metric=error_rate_expr,
            threshold=1.0,
            comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
            evaluation_periods=3,
            datapoints_to_alarm=2,
            treat_missing_data=cloudwatch.TreatMissingData.NOT_BREACHING,
            alarm_description="Alarm when API Gateway error rate exceeds 1% over 5-minute periods.",
        )

        sns_action = cloudwatch_actions.SnsAction(oncall_topic)
        error_rate_alarm.add_alarm_action(sns_action)
        error_rate_alarm.add_ok_action(sns_action)

        CfnOutput(self, "OnCallTopicArn", value=oncall_topic.topic_arn, export_name=f"{self.stack_name}:OnCallTopicArn")
        CfnOutput(self, "ErrorRateAlarmName", value=error_rate_alarm.alarm_name, export_name=f"{self.stack_name}:ErrorRateAlarmName")