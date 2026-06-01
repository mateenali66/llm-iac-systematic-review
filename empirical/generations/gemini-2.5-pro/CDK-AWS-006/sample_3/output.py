from aws_cdk import (
    Stack,
    aws_iam as iam,
    CfnParameter,
    CfnOutput,
    RemovalPolicy
)
from constructs import Construct

class CrossAccountLambdaRoleStack(Stack):
    """
    Defines an IAM role for cross-account access, allowing a partner AWS account
    to invoke specific Lambda functions.
    """
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        partner_account_id = CfnParameter(self, "PartnerAccountId",
            type="String",
            description="The AWS Account ID of the partner that will assume this role.",
            min_length=12,
            max_length=12,
            allowed_pattern=r"^\d{12}$",
            constraint_description="Partner Account ID must be a 12-digit number."
        )

        target_lambda_arns_param = CfnParameter(self, "TargetLambdaArns",
            type="CommaDelimitedList",
            description="Comma-separated list of Lambda function ARNs that the partner can invoke."
        )

        cross_account_role = iam.Role(self, "PartnerLambdaInvokeRole",
            role_name="PartnerLambdaInvokeRole",
            description="Role for partner account to invoke specific Lambda functions",
            assumed_by=iam.AccountPrincipal(partner_account_id.value_as_string),
            max_session_duration=cdk.Duration.hours(1)
        )

        invoke_lambda_policy = iam.Policy(self, "LambdaInvokePolicy",
            policy_name="PartnerLambdaInvokePolicy",
            statements=[
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=["lambda:InvokeFunction"],
                    resources=target_lambda_arns_param.value_as_list
                )
            ]
        )

        cross_account_role.attach_inline_policy(invoke_lambda_policy)

        CfnOutput(self, "CrossAccountRoleArnOutput",
            value=cross_account_role.role_arn,
            description="The ARN of the IAM role for the partner to assume.",
            export_name=f"{self.stack_name}-CrossAccountRoleArn"
        )