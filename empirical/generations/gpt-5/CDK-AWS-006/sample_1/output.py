from aws_cdk import (
    App,
    Stack,
    CfnParameter,
    CfnOutput,
    Duration,
    Fn,
    Tags,
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
            description="12-digit AWS Account ID of the partner allowed to assume this role.",
            allowed_pattern="\\d{12}",
            constraint_description="Must be a 12-digit AWS account ID.",
        )

        external_id = CfnParameter(
            self,
            "ExternalId",
            type="String",
            description="External ID required for assuming this role (share securely with partner).",
            min_length=2,
            max_length=1224,
            no_echo=True,
        )

        lambda_function_arns = CfnParameter(
            self,
            "LambdaFunctionArns",
            type="List<String>",
            description="List of Lambda function ARNs that the partner can invoke.",
        )

        role = iam.Role(
            self,
            "PartnerInvokeLambdaRole",
            role_name="PartnerInvokeLambdaRole",
            assumed_by=iam.AccountPrincipal(partner_account_id.value_as_string).with_conditions(
                {
                    "StringEquals": {
                        "sts:ExternalId": external_id.value_as_string,
                    }
                }
            ),
            description="Cross-account role assumed by partner to invoke specific Lambda functions.",
            max_session_duration=Duration.hours(1),
        )

        resources = []
        for arn in lambda_function_arns.value_as_list:
            resources.append(arn)
            resources.append(Fn.join("", [arn, ":*"]))

        invoke_policy = iam.Policy(
            self,
            "InvokeSpecificLambdasPolicy",
            statements=[
                iam.PolicyStatement(
                    sid="AllowInvokeSpecificLambdas",
                    actions=["lambda:InvokeFunction"],
                    resources=resources,
                    effect=iam.Effect.ALLOW,
                )
            ],
        )
        role.attach_inline_policy(invoke_policy)

        Tags.of(role).add("managed-by", "cdk")
        Tags.of(role).add("purpose", "cross-account-lambda-invoke")
        Tags.of(role).add("security:classification", "restricted")

        CfnOutput(self, "PartnerInvokeRoleArn", value=role.role_arn, description="ARN of the cross-account role.")
        CfnOutput(self, "PartnerInvokeRoleName", value=role.role_name, description="Name of the cross-account role.")


app = App()
CrossAccountLambdaInvokeRoleStack(app, "CrossAccountLambdaInvokeRoleStack")
app.synth()