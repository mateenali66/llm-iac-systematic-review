from aws_cdk import (
    Stack,
    CfnOutput,
    Duration,
    aws_iam as iam,
)
from constructs import Construct


class CrossAccountLambdaInvokeRoleStack(Stack):
    """
    Creates an IAM role that a trusted partner AWS account can assume
    in order to invoke a specific, explicit allow-list of Lambda functions.

    Security best practices applied:
      * Trust policy restricted to the partner account principal.
      * sts:ExternalId condition enforced to mitigate the confused deputy problem.
      * Optional MFA condition for human (non-service) assumers.
      * Permissions scoped to explicit Lambda function ARNs (no wildcards).
      * Only lambda:InvokeFunction (+ GetFunction for metadata) is granted.
      * Max session duration set to 1 hour.
    """

    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        partner_account_id: str,
        external_id: str,
        invokable_lambda_arns: list[str],
        require_mfa: bool = False,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        if not partner_account_id or len(partner_account_id) != 12 or not partner_account_id.isdigit():
            raise ValueError("partner_account_id must be a 12-digit AWS account ID.")
        if not external_id or len(external_id) < 16:
            raise ValueError(
                "external_id must be a strong, unguessable shared secret (>= 16 chars)."
            )
        if not invokable_lambda_arns:
            raise ValueError("At least one Lambda function ARN must be provided.")

        # Build trust policy conditions
        conditions: dict = {
            "StringEquals": {"sts:ExternalId": external_id},
        }
        if require_mfa:
            conditions["Bool"] = {"aws:MultiFactorAuthPresent": "true"}

        principal = iam.AccountPrincipal(partner_account_id).with_conditions(conditions)

        role = iam.Role(
            self,
            "PartnerCrossAccountLambdaInvokeRole",
            role_name="PartnerCrossAccountLambdaInvokeRole",
            description=(
                f"Cross-account role assumed by partner account {partner_account_id} "
                "to invoke an explicit allow-list of Lambda functions."
            ),
            assumed_by=principal,
            max_session_duration=Duration.hours(1),
        )

        # Least-privilege inline policy: explicit ARNs, no wildcards.
        role.attach_inline_policy(
            iam.Policy(
                self,
                "InvokeAllowedLambdasPolicy",
                policy_name="InvokeAllowedLambdasPolicy",
                statements=[
                    iam.PolicyStatement(
                        sid="InvokeAllowListedLambdas",
                        effect=iam.Effect.ALLOW,
                        actions=[
                            "lambda:InvokeFunction",
                        ],
                        resources=invokable_lambda_arns,
                    ),
                    iam.PolicyStatement(
                        sid="DescribeAllowListedLambdas",
                        effect=iam.Effect.ALLOW,
                        actions=[
                            "lambda:GetFunction",
                            "lambda:GetFunctionConfiguration",
                        ],
                        resources=invokable_lambda_arns,
                    ),
                ],
            )
        )

        CfnOutput(
            self,
            "RoleArn",
            value=role.role_arn,
            description="ARN of the cross-account Lambda invoke role.",
            export_name="PartnerCrossAccountLambdaInvokeRoleArn",
        )
        CfnOutput(
            self,
            "TrustedPartnerAccount",
            value=partner_account_id,
            description="Partner AWS account ID trusted to assume the role.",
        )
        CfnOutput(
            self,
            "ExternalIdHint",
            value="Configured (value not exported for security).",
            description="ExternalId is required on sts:AssumeRole; share out-of-band.",
        )


# Example app wiring -----------------------------------------------------------
import os
from aws_cdk import App, Environment

app = App()

partner_account_id = app.node.try_get_context("partnerAccountId") or "111122223333"
external_id = app.node.try_get_context("externalId") or os.environ.get(
    "PARTNER_EXTERNAL_ID", "REPLACE_WITH_STRONG_SHARED_SECRET_VALUE"
)
invokable_lambda_arns = app.node.try_get_context("invokableLambdaArns") or [
    f"arn:aws:lambda:{os.environ.get('CDK_DEFAULT_REGION', 'us-east-1')}:"
    f"{os.environ.get('CDK_DEFAULT_ACCOUNT', '000000000000')}:function:PartnerInvokable-Example"
]
require_mfa = bool(app.node.try_get_context("requireMfa") or False)

CrossAccountLambdaInvokeRoleStack(
    app,
    "CrossAccountLambdaInvokeRoleStack",
    partner_account_id=partner_account_id,
    external_id=external_id,
    invokable_lambda_arns=invokable_lambda_arns,
    require_mfa=require_mfa,
    env=Environment(
        account=os.environ.get("CDK_DEFAULT_ACCOUNT"),
        region=os.environ.get("CDK_DEFAULT_REGION"),
    ),
    description="IAM role granting a partner AWS account invoke access to specific Lambdas.",
)

app.synth()