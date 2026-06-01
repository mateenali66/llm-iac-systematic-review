from aws_cdk import (
    Stack,
    CfnParameter,
    Duration,
    CfnOutput,
)
from aws_cdk import aws_iam as iam
from constructs import Construct


class CrossAccountLambdaInvokeRoleStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        partner_account_id = CfnParameter(
            self,
            "PartnerAccountId",
            type="String",
            description="AWS Account ID of the partner who will assume the role."
        )

        external_id = CfnParameter(
            self,
            "ExternalId",
            type="String",
            no_echo=True,
            description="External ID required by the partner to assume this role."
        )

        allowed_lambda_arns = CfnParameter(
            self,
            "AllowedLambdaArns",
            type="CommaDelimitedList",
            description="Comma-delimited list of Lambda function ARNs that this role can invoke. Include aliases/versions as needed."
        )

        role_name = CfnParameter(
            self,
            "RoleName",
            type="String",
            default="PartnerInvokeLambdaRole",
            description="Name of the IAM role to create."
        )

        assumed_by = iam.AccountPrincipal(partner_account_id.value_as_string).with_conditions({
            "StringEquals": {
                "sts:ExternalId": external_id.value_as_string
            }
        })

        role = iam.Role(
            self,
            "CrossAccountLambdaInvokeRole",
            role_name=role_name.value_as_string,
            assumed_by=assumed_by,
            description="Role assumed by a partner account to invoke specific Lambda functions cross-account.",
            max_session_duration=Duration.hours(1)
        )

        role.add_to_policy(
            iam.PolicyStatement(
                actions=["lambda:InvokeFunction"],
                resources=allowed_lambda_arns.value_as_list
            )
        )

        CfnOutput(self, "RoleArn", value=role.role_arn)
        CfnOutput(self, "RoleName", value=role.role_name)