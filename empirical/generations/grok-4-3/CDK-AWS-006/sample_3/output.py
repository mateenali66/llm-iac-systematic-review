from aws_cdk import App, Stack, Environment
from aws_cdk.aws_iam import Role, AccountPrincipal, PolicyStatement, Effect
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

        assume_role_principal = AccountPrincipal(partner_account_id)
        if external_id:
            assume_role_principal = assume_role_principal.with_conditions(
                {"StringEquals": {"sts:ExternalId": external_id}}
            )

        role = Role(
            self,
            "PartnerCrossAccountInvokeRole",
            role_name="PartnerLambdaInvokeRole",
            assumed_by=assume_role_principal,
            description="Cross-account role allowing partner account to invoke specific Lambda functions",
            max_session_duration=3600,
        )

        invoke_policy = PolicyStatement(
            effect=Effect.ALLOW,
            actions=["lambda:InvokeFunction", "lambda:InvokeAsync"],
            resources=lambda_function_arns,
        )
        role.add_to_policy(invoke_policy)


app = App()
CrossAccountLambdaInvokeRoleStack(
    app,
    "CrossAccountLambdaInvokeRoleStack",
    partner_account_id="123456789012",
    lambda_function_arns=[
        "arn:aws:lambda:us-east-1:111111111111:function:PartnerAllowedFunction1",
        "arn:aws:lambda:us-east-1:111111111111:function:PartnerAllowedFunction2",
    ],
    external_id="partner-unique-external-id-12345",
    env=Environment(account="111111111111", region="us-east-1"),
)
app.synth()