from aws_cdk import (
    aws_iam as iam,
    aws_lambda as lambda_,
    Stack,
    aws_ssm as ssm,
    CfnOutput,
)
from constructs import Construct

class CrossAccountLambdaInvocationStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Configuration - these should be stored in context or SSM Parameter Store in production
        partner_account_id = self.node.try_get_context("partner_account_id")
        if not partner_account_id:
            partner_account_id = ssm.StringParameter.value_from_lookup(
                self, "/cross-account/partner-account-id"
            )

        # List of Lambda function ARNs that the partner can invoke
        # In production, retrieve from SSM or a config file
        lambda_function_arns = [
            "arn:aws:lambda:us-east-1:123456789012:function:MyFunction1",
            "arn:aws:lambda:us-east-1:123456789012:function:MyFunction2",
        ]

        # Create the IAM role for cross-account access
        cross_account_role = iam.Role(
            self,
            "CrossAccountLambdaInvocationRole",
            assumed_by=iam.AccountPrincipal(partner_account_id),
            description="Role for partner account to invoke specific Lambda functions",
            role_name="CrossAccountLambdaInvocationRole",
            max_session_duration=iam.Duration.hours(1),
        )

        # Attach a policy that allows invoking only the specified Lambda functions
        cross_account_role.add_to_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "lambda:InvokeFunction",
                    "lambda:InvokeAsync",
                ],
                resources=lambda_function_arns,
            )
        )

        # Optional: Add a condition to restrict access to specific source IPs or VPC
        # This is a placeholder - adjust based on your security requirements
        # cross_account_role.assume_role_policy.add_statements(
        #     iam.PolicyStatement(
        #         effect=iam.Effect.DENY,
        #         principals=[iam.AnyPrincipal()],
        #         actions=["sts:AssumeRole"],
        #         conditions={
        #             "NotIpAddress": {"aws:SourceIp": ["203.0.113.0/24"]}
        #         }
        #     )
        # )

        # Output the role ARN for the partner to use
        CfnOutput(
            self,
            "CrossAccountRoleArn",
            value=cross_account_role.role_arn,
            description="ARN of the cross-account IAM role for Lambda invocation",
        )

        # Optional: Store the role ARN in SSM Parameter Store for easy retrieval
        ssm.StringParameter(
            self,
            "CrossAccountRoleArnParameter",
            parameter_name="/cross-account/lambda-invocation-role-arn",
            string_value=cross_account_role.role_arn,
            description="ARN of the cross-account IAM role for Lambda invocation",
        )