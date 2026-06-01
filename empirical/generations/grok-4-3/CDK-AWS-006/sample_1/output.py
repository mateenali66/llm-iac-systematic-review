from aws_cdk import Stack, aws_iam as iam, CfnParameter
from constructs import Construct
from typing import List


class CrossAccountLambdaInvokeRoleStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        partner_account_id: str,
        lambda_function_arns: List[str],
        external_id: str = None,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        if not partner_account_id or not lambda_function_arns:
            raise ValueError("partner_account_id and lambda_function_arns are required")

        assume_role_principal = iam.AccountPrincipal(partner_account_id)
        conditions = {}
        if external_id:
            conditions = {"StringEquals": {"sts:ExternalId": external_id}}

        role = iam.Role(
            self,
            "PartnerCrossAccountInvokeRole",
            role_name="PartnerCrossAccountLambdaInvokeRole",
            assumed_by=assume_role_principal,
            external_ids=[external_id] if external_id else None,
            description="Role allowing partner account to invoke specific Lambda functions",
            max_session_duration=3600,
        )

        invoke_policy = iam.PolicyStatement(
            effect=iam.Effect.ALLOW,
            actions=["lambda:InvokeFunction"],
            resources=lambda_function_arns,
        )
        role.add_to_policy(invoke_policy)

        # Deny all other actions by default (least privilege enforced via explicit policy)
        role.add_to_policy(
            iam.PolicyStatement(
                effect=iam.Effect.DENY,
                actions=["*"],
                resources=["*"],
                conditions={"StringNotEquals": {"aws:RequestedRegion": self.region}},
            )
        )