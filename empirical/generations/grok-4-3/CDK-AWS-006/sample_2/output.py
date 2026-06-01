from aws_cdk import (
    Stack,
    aws_iam as iam,
)
from constructs import Construct
from typing import List


class CrossAccountLambdaInvokerStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        partner_account_id: str,
        lambda_function_arns: List[str],
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        statements = [
            iam.PolicyStatement(
                actions=["lambda:InvokeFunction"],
                resources=lambda_function_arns,
            )
        ]

        role = iam.Role(
            self,
            "PartnerCrossAccountInvokerRole",
            role_name="PartnerCrossAccountLambdaInvoker",
            assumed_by=iam.AccountPrincipal(partner_account_id),
            description="Role assumable by partner account to invoke specified Lambda functions",
            inline_policies={
                "LambdaInvokePolicy": iam.PolicyDocument(statements=statements)
            },
            max_session_duration=3600,
        )

        # Enforce least-privilege and prevent role from being assumed by other principals
        role.assume_role_policy.add_statements(
            iam.PolicyStatement(
                effect=iam.Effect.DENY,
                actions=["sts:AssumeRole"],
                principals=[iam.AnyPrincipal()],
                conditions={"StringNotEquals": {"aws:PrincipalAccount": partner_account_id}},
            )
        )