import aws_cdk as cdk
from aws_cdk import aws_iam as iam
from aws_cdk import aws_lambda as _lambda

class CrossAccountAccessStack(cdk.Stack):
    def __init__(self, scope: cdk.Construct, id: str, partner_account_id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        self.partner_account_id = partner_account_id

        self.lambda_function = _lambda.Function(
            self, 'LambdaFunction',
            runtime=_lambda.Runtime.PYTHON_3_9,
            handler='index.handler',
            code=_lambda.Code.from_asset('lambda')
        )

        self.cross_account_role = iam.Role(
            self, 'CrossAccountRole',
            assumed_by=iam.AccountPrincipal(self.partner_account_id)
        )

        self.cross_account_role.add_to_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    'lambda:InvokeFunction',
                ],
                resources=[self.lambda_function.function_arn]
            )
        )

        self.lambda_function.grant_invoke(self.cross_account_role)

        cdk.CfnOutput(
            self, 'CrossAccountRoleArn',
            value=self.cross_account_role.role_arn,
            description='The ARN of the cross-account role'
        )