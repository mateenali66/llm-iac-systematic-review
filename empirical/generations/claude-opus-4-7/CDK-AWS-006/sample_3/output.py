from typing import List, Optional, Sequence

from aws_cdk import (
    Stack,
    CfnOutput,
    Duration,
    aws_iam as iam,
)
from constructs import Construct


class CrossAccountLambdaInvokeRoleStack(Stack):
    """
    Creates an IAM role that a trusted partner AWS account can assume in order
    to invoke a specific, restricted set of Lambda functions in this account.

    Security best practices applied:
      - Principal scoped to the partner account root (partner should further
        restrict which IAM principals in their account may assume the role).
      - sts:ExternalId condition to mitigate the "confused deputy" problem.
      - Optional MFA requirement on assume-role (off by default for service-to-service).
      - Least-privilege: only lambda:InvokeFunction (and optional InvokeAsync) on
        explicitly listed function ARNs (including all versions/aliases).
      - Max session duration limited to 1 hour.
      - Permissions boundary attached to cap the role's effective permissions.
    """

    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        partner_account_id: str,
        external_id: str,
        invokable_lambda_arns: Sequence[str],
        role_name: Optional[str] = None,
        require_mfa: bool = False,
        allow_async_invoke: bool = False,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        if not partner_account_id or not partner_account_id.isdigit() or len(partner_account_id) != 12:
            raise ValueError("partner_account_id must be a 12-digit AWS account ID")
        if not external_id or len(external_id) < 16:
            raise ValueError(
                "external_id must be a strong, hard-to-guess secret (>= 16 characters)"
            )
        if not invokable_lambda_arns:
            raise ValueError("At least one Lambda ARN must be supplied")

        # Expand each function ARN to also cover versions and aliases (':*').
        resource_arns: List[str] = []
        for arn in invokable_lambda_arns:
            resource_arns.append(arn)
            if not arn.endswith(":*"):
                resource_arns.append(f"{arn}:*")

        # Build the assume-role conditions.
        assume_conditions = {
            "StringEquals": {"sts:ExternalId": external_id},
        }
        if require_mfa:
            assume_conditions["Bool"] = {"aws:MultiFactorAuthPresent": "true"}
            assume_conditions["NumericLessThan"] = {"aws:MultiFactorAuthAge": "3600"}

        principal = iam.PrincipalWithConditions(
            iam.AccountPrincipal(partner_account_id),
            assume_conditions,
        )

        # Permissions boundary to cap maximum permissions, even if the inline
        # policy is later expanded by mistake.
        boundary = iam.ManagedPolicy(
            self,
            "CrossAccountInvokeBoundary",
            managed_policy_name=None,
            description="Permissions boundary for cross-account Lambda invoke role.",
            statements=[
                iam.PolicyStatement(
                    sid="AllowOnlyLambdaInvoke",
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "lambda:InvokeFunction",
                        "lambda:InvokeAsync",
                    ],
                    resources=["*"],
                ),
            ],
        )

        self.role = iam.Role(
            self,
            "CrossAccountLambdaInvokeRole",
            role_name=role_name,
            assumed_by=principal,
            description=(
                f"Cross-account role assumable by account {partner_account_id} "
                f"to invoke a restricted set of Lambda functions."
            ),
            max_session_duration=Duration.hours(1),
            permissions_boundary=boundary,
        )

        invoke_actions = ["lambda:InvokeFunction"]
        if allow_async_invoke:
            invoke_actions.append("lambda:InvokeAsync")

        self.role.add_to_policy(
            iam.PolicyStatement(
                sid="AllowInvokeSpecificLambdaFunctions",
                effect=iam.Effect.ALLOW,
                actions=invoke_actions,
                resources=resource_arns,
            )
        )

        # Explicit deny for any destructive / management actions as defense in depth.
        self.role.add_to_policy(
            iam.PolicyStatement(
                sid="DenyLambdaManagement",
                effect=iam.Effect.DENY,
                actions=[
                    "lambda:CreateFunction",
                    "lambda:DeleteFunction",
                    "lambda:UpdateFunctionCode",
                    "lambda:UpdateFunctionConfiguration",
                    "lambda:AddPermission",
                    "lambda:RemovePermission",
                    "lambda:PutFunctionConcurrency",
                    "lambda:DeleteFunctionConcurrency",
                    "iam:*",
                ],
                resources=["*"],
            )
        )

        CfnOutput(
            self,
            "CrossAccountRoleArn",
            value=self.role.role_arn,
            description="ARN of the cross-account Lambda invoke role. Share with the partner.",
            export_name=f"{construct_id}-RoleArn",
        )
        CfnOutput(
            self,
            "PartnerAccountId",
            value=partner_account_id,
            description="Trusted partner AWS account ID.",
        )
        CfnOutput(
            self,
            "ExternalIdHint",
            value="Configured (value not exported for security).",
            description="An sts:ExternalId is required to assume this role.",
        )


# ---------------------------------------------------------------------------
# App entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":