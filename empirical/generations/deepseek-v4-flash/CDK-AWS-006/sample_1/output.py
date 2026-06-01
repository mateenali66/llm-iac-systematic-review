from aws_cdk import (
    aws_iam as iam,
    aws_lambda as lambda_,
    Stack,
    aws_ssm as ssm,
    CfnOutput,
)
from constructs import Construct

class CrossAccountLambdaInvokerStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Configuration - adjust these values as needed
        partner_account_id = ssm.StringParameter.from_string_parameter_name(
            self, "PartnerAccountIdParam",
            string_parameter_name="/cross-account/partner-account-id"
        ).string_value

        lambda_function_arns = [
            ssm.StringParameter.from_string_parameter_name(
                self, f"LambdaArnParam{i}",
                string_parameter_name=f"/cross-account/lambda-arn-{i}"
            ).string_value
            for i in range(1, 4)  # Adjust range for number of functions
        ]

        # Create the IAM role for cross-account access
        cross_account_role = iam.Role(
            self, "CrossAccountLambdaInvokerRole",
            assumed_by=iam.AccountPrincipal(partner_account_id),
            description="Role for cross-account Lambda invocation",
            role_name="CrossAccountLambdaInvokerRole",
            max_session_duration=iam.Duration.hours(1),
        )

        # Grant invoke permissions on each Lambda function
        for i, function_arn in enumerate(lambda_function_arns):
            lambda_function = lambda_.Function.from_function_arn(
                self, f"TargetLambda{i}",
                function_arn=function_arn
            )
            lambda_function.grant_invoke(cross_account_role)

        # Output the role ARN for reference
        CfnOutput(
            self, "CrossAccountRoleArn",
            value=cross_account_role.role_arn,
            description="ARN of the cross-account IAM role"
        )