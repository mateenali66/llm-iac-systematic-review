from aws_cdk import (
    Stack,
    aws_iam as iam,
    aws_lambda as _lambda,
    Duration,
    ArnFormat,
    CfnOutput
)
from constructs import Construct

class CrossAccountLambdaAccessStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Partner account ID that will be allowed to invoke Lambda functions
        partner_account_id = "123456789012"
        
        # Create IAM role for cross-account access
        cross_account_role = iam.Role(
            self, "CrossAccountLambdaInvokeRole",
            assumed_by=iam.AccountPrincipal(partner_account_id),
            role_name="CrossAccountLambdaInvokeRole",
            description="Role allowing cross-account Lambda function invocation",
            max_session_duration=Duration.hours(1)
        )
        
        # Define specific Lambda functions that can be invoked
        lambda_functions = []
        for i in range(1, 3):
            lambda_function = _lambda.Function(
                self, f"TargetFunction{i}",
                runtime=_lambda.Runtime.PYTHON_3_9,
                handler="index.handler",
                code=_lambda.Code.from_inline("""
def handler(event, context):
    return {'statusCode': 200, 'body': 'Hello from Lambda!'}
"""),
                function_name=f"cross-account-target-{i}",
                description=f"Target Lambda function {i} for cross-account access"
            )
            lambda_functions.append(lambda_function)
        
        # Add permissions to invoke specific Lambda functions
        for idx, lambda_func in enumerate(lambda_functions):
            iam.Policy(
                self, f"LambdaInvokePolicy{idx+1}",
                roles=[cross_account_role],
                policy_name="CrossAccountLambdaInvokePolicy",
                statements=[
                    iam.PolicyStatement(
                        effect=iam.Effect.ALLOW,
                        actions=["lambda:InvokeFunction"],
                        resources=[lambda_func.function_arn]
                    )
                ]
            )
        
        # Output the role ARN for the partner account to use
        CfnOutput(
            self, "CrossAccountRoleArn",
            value=cross_account_role.role_arn,
            export_name="CrossAccountLambdaInvokeRoleArn"
        )