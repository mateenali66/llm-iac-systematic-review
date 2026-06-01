from aws_cdk import (
    aws_iam as iam,
    aws_lambda as lambda_,
    Stack,
    aws_ssm as ssm,
    CfnOutput,
    RemovalPolicy,
    Duration,
)
from constructs import Construct

class CrossAccountLambdaInvocationStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Configuration - these should be stored in SSM Parameter Store or context
        partner_account_id = ssm.StringParameter.from_string_parameter_name(
            self, "PartnerAccountId",
            string_parameter_name="/cross-account/partner-account-id"
        ).string_value

        # Lambda function ARNs that the partner can invoke
        lambda_function_arns = [
            ssm.StringParameter.from_string_parameter_name(
                self, f"LambdaArn{i}",
                string_parameter_name=f"/cross-account/lambda-arn-{i}"
            ).string_value
            for i in range(1, 4)  # Adjust range as needed
        ]

        # Create the Lambda functions (example - replace with actual functions)
        lambda_functions = []
        for i, arn in enumerate(lambda_function_arns):
            # In production, these would be imported or created elsewhere
            # This is a placeholder - you would typically reference existing functions
            fn = lambda_.Function.from_function_arn(
                self, f"ImportedLambda{i}",
                function_arn=arn
            )
            lambda_functions.append(fn)

        # Create the IAM role for cross-account access
        cross_account_role = iam.Role(
            self, "CrossAccountLambdaInvocationRole",
            assumed_by=iam.AccountPrincipal(partner_account_id),
            role_name="CrossAccountLambdaInvocationRole",
            description="Role for partner account to invoke specific Lambda functions",
            max_session_duration=Duration.hours(1),
        )

        # Grant invoke permissions to the specific Lambda functions
        for fn in lambda_functions:
            fn.grant_invoke(cross_account_role)

        # Explicit policy statement for clarity and additional control
        cross_account_role.add_to_policy(
            iam.PolicyStatement(
                actions=["lambda:InvokeFunction"],
                resources=lambda_function_arns,
                conditions={
                    "StringEquals": {
                        "aws:SourceAccount": partner_account_id
                    }
                }
            )
        )

        # Output the role ARN for reference
        CfnOutput(
            self, "CrossAccountRoleArn",
            value=cross_account_role.role_arn,
            description="ARN of the cross-account IAM role"
        )

        # Optional: Add a trust policy condition for additional security
        cross_account_role.assume_role_policy.add_statements(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                principals=[iam.AccountPrincipal(partner_account_id)],
                actions=["sts:AssumeRole"],
                conditions={
                    "StringEquals": {
                        "sts:ExternalId": ssm.StringParameter.from_string_parameter_name(
                            self, "ExternalId",
                            string_parameter_name="/cross-account/external-id"
                        ).string_value
                    }
                }
            )
        )