from aws_cdk import (
    Stack,
    aws_iam as iam,
    aws_lambda as _lambda,
    Duration,
    ArnFormat,
    Arn
)
from constructs import Construct

class CrossAccountLambdaAccessStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Partner account ID that will be granted access
        partner_account_id = "123456789012"
        
        # Define specific Lambda functions that can be invoked
        lambda_function_1 = _lambda.Function(
            self, "Function1",
            runtime=_lambda.Runtime.PYTHON_3_9,
            handler="index.handler",
            code=_lambda.Code.from_inline("""
def handler(event, context):
    return {'statusCode': 200, 'body': 'Hello from Function 1'}
"""),
            function_name="cross-account-function-1"
        )
        
        lambda_function_2 = _lambda.Function(
            self, "Function2",
            runtime=_lambda.Runtime.PYTHON_3_9,
            handler="index.handler",
            code=_lambda.Code.from_inline("""
def handler(event, context):
    return {'statusCode': 200, 'body': 'Hello from Function 2'}
"""),
            function_name="cross-account-function-2"
        )

        # Create IAM role for cross-account access
        cross_account_role = iam.Role(
            self, "CrossAccountLambdaInvokeRole",
            assumed_by=iam.AccountPrincipal(partner_account_id),
            role_name="CrossAccountLambdaInvokeRole",
            description="Role allowing partner account to invoke specific Lambda functions",
            max_session_duration=Duration.hours(1)
        )

        # Attach policy to allow invocation of specific Lambda functions
        lambda_invoke_policy = iam.Policy(
            self, "LambdaInvokePolicy",
            policy_name="CrossAccountLambdaInvokePolicy",
            statements=[
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "lambda:InvokeFunction",
                        "lambda:InvokeAsync"
                    ],
                    resources=[
                        lambda_function_1.function_arn,
                        lambda_function_2.function_arn
                    ]
                )
            ]
        )
        
        cross_account_role.attach_inline_policy(lambda_invoke_policy)

        # Output the role ARN for partner account reference
        cross_account_role_arn = cross_account_role.role_arn