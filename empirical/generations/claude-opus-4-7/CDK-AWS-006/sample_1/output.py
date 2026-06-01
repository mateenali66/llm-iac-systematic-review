from typing import List, Optional

from aws_cdk import (
    Stack,
    CfnOutput,
    Duration,
    aws_iam as iam,
)
from constructs import Construct


class CrossAccountLambdaInvokeStack(Stack):
    """
    Creates an IAM role assumable by a trusted partner AWS account, granting
    the principal permission to invoke a specific set of Lambda functions.

    Security best practices applied:
      - Trust policy restricted to a single partner account principal.
      - External ID condition to mitigate the confused deputy problem.
      - Optional MFA condition for human-assumed roles.
      - Least-privilege: only lambda:InvokeFunction (and async variant) on
        explicitly listed function ARNs (no wildcards).
      - Max session duration explicitly set.
      - Permissions boundary support (optional) to cap effective permissions.
    """

    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        partner_account_id: str,
        external_id: str,
        invokable_lambda_arns: List[str],
        require_mfa: bool = False,
        max_session_duration_hours: int = 1,
        permissions_boundary_arn: Optional[str] = None,
        role_name: Optional[str] = "PartnerCrossAccountLambdaInvokeRole",
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        if not partner_account_id or not partner_account_id.isdigit() or len(partner_account_id) != 12:
            raise ValueError("partner_account_id must be a 12-digit AWS account ID string.")
        if not external_id or len(external_id) < 16:
            raise ValueError("external_id must be provided and be at least 16 characters long.")
        if not invokable_lambda_arns:
            raise ValueError("invokable_lambda_arns must contain at least one Lambda function ARN.")
        for arn in invokable_lambda_arns:
            if not arn.startswith("arn:aws:lambda:") and not arn.startswith("arn:aws-us-gov:lambda:"):
                raise ValueError(f"Invalid Lambda function ARN: {arn}")

        # Build the trust policy conditions.
        conditions = {
            "StringEquals": {"sts:ExternalId": external_id},
        }
        if require_mfa:
            conditions["Bool"] = {"aws:MultiFactorAuthPresent": "true"}
            conditions["NumericLessThan"] = {"aws:MultiFactorAuthAge": "3600"}

        trusted_principal = iam.AccountPrincipal(partner_account_id).with_conditions(conditions)

        permissions_boundary = (
            iam.ManagedPolicy.from_managed_policy_arn(
                self, "PermissionsBoundary", permissions_boundary_arn
            )
            if permissions_boundary_arn
            else None
        )

        self.role = iam.Role(
            self,
            "PartnerCrossAccountLambdaInvokeRole",
            role_name=role_name,
            assumed_by=trusted_principal,
            description=(
                f"Cross-account role assumable by AWS account {partner_account_id} "
                "to invoke a specific set of Lambda functions."
            ),
            max_session_duration=Duration.hours(max_session_duration_hours),
            permissions_boundary=permissions_boundary,
        )

        # Include function version/alias qualified ARNs as well.
        resource_arns: List[str] = []
        for arn in invokable_lambda_arns:
            resource_arns.append(arn)
            resource_arns.append(f"{arn}:*")

        self.role.add_to_policy(
            iam.PolicyStatement(
                sid="AllowInvokeSpecificLambdaFunctions",
                effect=iam.Effect.ALLOW,
                actions=[
                    "lambda:InvokeFunction",
                    "lambda:InvokeAsync",
                ],
                resources=resource_arns,
            )
        )

        # Explicit deny for any other Lambda mutating actions as defense-in-depth.
        self.role.add_to_policy(
            iam.PolicyStatement(
                sid="DenyLambdaManagementActions",
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
                ],
                resources=["*"],
            )
        )

        CfnOutput(
            self,
            "RoleArn",
            value=self.role.role_arn,
            description="ARN of the cross-account Lambda invoke role.",
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
            "InvokableLambdaArns",
            value=",".join(invokable_lambda_arns),
            description="Lambda function ARNs the role is permitted to invoke.",
        )