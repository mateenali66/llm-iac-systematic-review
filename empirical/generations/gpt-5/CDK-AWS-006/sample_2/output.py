from typing import Optional, Sequence, List
from constructs import Construct
from aws_cdk import (
    Stack,
    Duration,
    aws_iam as iam,
    aws_lambda as lambda_,
)


class CrossAccountLambdaInvokeRoleStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        partner_account_id: str,
        functions: Optional[Sequence[lambda_.IFunction]] = None,
        function_arns: Optional[Sequence[str]] = None,
        partner_role_arn: Optional[str] = None,
        external_id: Optional[str] = None,
        role_name: Optional[str] = None,
        max_session_duration: Optional[Duration] = None,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        if not partner_account_id or len(partner_account_id) != 12 or not partner_account_id.isdigit():
            raise ValueError("partner_account_id must be a 12-digit AWS account ID")

        if not functions and not function_arns:
            raise ValueError("Provide at least one of: functions or function_arns")

        # Define trusted principal (prefer a specific role in the partner account if provided)
        trusted_principal: iam.IPrincipal
        if partner_role_arn:
            trusted_principal = iam.ArnPrincipal(partner_role_arn)
        else:
            trusted_principal = iam.AccountPrincipal(partner_account_id)

        # Add external ID condition to trust policy if provided
        if external_id:
            trusted_principal = iam.PrincipalWithConditions(
                trusted_principal,
                {
                    "StringEquals": {
                        "sts:ExternalId": external_id
                    }
                }
            )

        role = iam.Role(
            self,
            "PartnerLambdaInvokeRole",
            role_name=role_name,
            assumed_by=trusted_principal,
            description="Role assumed by partner to invoke explicitly allowed Lambda functions.",
            max_session_duration=max_session_duration or Duration.hours(1),
        )

        # Grant invoke permissions for provided function constructs
        if functions:
            for fn in functions:
                fn.grant_invoke(role)

        # Grant invoke permissions for explicitly provided Lambda ARNs
        if function_arns:
            # Deduplicate ARNs
            unique_arns: List[str] = list(dict.fromkeys(function_arns))

            # Allow invoking the specified functions
            role.add_to_policy(
                iam.PolicyStatement(
                    sid="InvokeSpecificLambdaArns",
                    actions=["lambda:InvokeFunction"],
                    resources=unique_arns,
                )
            )
            # Also allow invoking any versions/aliases of those functions
            role.add_to_policy(
                iam.PolicyStatement(
                    sid="InvokeSpecificLambdaVersionsAndAliases",
                    actions=["lambda:InvokeFunction"],
                    resources=[f"{arn}:*" for arn in unique_arns],
                )
            )