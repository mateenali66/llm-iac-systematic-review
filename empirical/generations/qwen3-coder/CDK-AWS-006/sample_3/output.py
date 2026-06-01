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

        # Partner account ID that will be granted access
        partner_account_id = "123456789012"
        
        # Create the IAM role in this account for cross-account access
        cross_account_role = iam.Role(
            self, "CrossAccountLambdaInvokeRole",
            assumed_by=iam.AccountPrincipal(partner_account_id),
            role_name="CrossAccountLambdaInvokeRole",
            description="Role for cross-account Lambda function invocation"
        )
        
        # Define specific Lambda functions that can be invoked
        lambda_function_1 = _lambda.Function(
            self, "ProcessingFunction1",
            runtime=_lambda.Runtime.PYTHON_3_9,
            handler="index.handler",
            code=_lambda.Code.from_inline("""
def handler(event, context):
    return {'statusCode': 200, 'body': 'Hello from Function 1'}
"""),
            function_name="CrossAccountProcessingFunction1",
            timeout=Duration.seconds(30)
        )
        
        lambda_function_2 = _lambda.Function(
            self, "ProcessingFunction2",
            runtime=_lambda.Runtime.PYTHON_3_9,
            handler="index.handler",
            code=_lambda.Code.from_inline("""
def handler(event, context):
    return {'statusCode': 200, 'body': 'Hello from Function 2'}
"""),
            function_name="CrossAccountProcessingFunction2",
            timeout=Duration.seconds(30)
        )
        
        # Grant invoke permissions to the cross-account role
        lambda_function_1.grant_invoke(cross_account_role)
        lambda_function_2.grant_invoke(cross_account_role)
        
        # Explicitly add policy statement for more granular control
        cross_account_role.add_to_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "lambda:InvokeFunction"
                ],
                resources=[
                    lambda_function_1.function_arn,
                    lambda_function_2.function_arn
                ]
            )
        )
        
        # Output the role ARN for the partner account to use
        CfnOutput(
            self, "CrossAccountRoleArn",
            value=cross_account_role.role_arn,
            export_name="CrossAccountLambdaInvokeRoleArn"
        )