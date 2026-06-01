from aws_cdk import (
    Stack,
    aws_iam as iam,
    CfnOutput,
    Aws
)
from constructs import Construct

class CrossAccountLambdaInvokerStack(Stack):
    """
    Defines an IAM role for a partner AWS account to invoke specific Lambda functions.
    """
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # --- Configuration ---
        # Replace with the actual AWS account ID of your partner.
        # For production, consider using CDK context or SSM Parameter Store.
        partner_account_id = "123456789012"

        # Replace with the ARNs of the Lambda functions the partner can invoke.
        # Using pseudo-parameters to construct ARNs dynamically.
        invokable_lambda_arns = [
            f"arn:{Aws.PARTITION}:lambda:{Aws.REGION}:{Aws.ACCOUNT_ID}:function:MyFunction-A",
            f"arn:{Aws.PARTITION}:lambda:{Aws.REGION}:{Aws.ACCOUNT_ID}:function:MyFunction-B",
        ]
        # --- End Configuration ---

        if not invokable_lambda_arns:
            raise ValueError("invokable_lambda_arns list cannot be empty.")

        if partner_account_id == "123456789012":
            print("Warning: Using a placeholder partner account ID. Please replace '123456789012' with a real account ID.")

        # Define the trusted principal that is allowed to assume this role.
        # This is the root of the partner's AWS account.
        trusted_principal = iam.AccountPrincipal(partner_account_id)

        # Create the IAM role for cross-account access.
        cross_account_role = iam.Role(
            self,
            "PartnerLambdaInvokerRole",
            role_name="PartnerLambdaAccessRole",
            assumed_by=trusted_principal,
            description=f"Role for partner account {partner_account_id} to invoke specific Lambda functions."
        )

        # Create a policy statement that grants permission to invoke the specified Lambda functions.
        # This adheres to the principle of least privilege.
        invoke_lambda_policy_statement = iam.PolicyStatement(
            effect=iam.Effect.ALLOW,
            actions=["lambda:InvokeFunction"],
            resources=invokable_lambda_arns
        )

        # Attach the inline policy to the role.
        cross_account_role.add_to_policy(invoke_lambda_policy_statement)

        # Output the ARN of the created role so the partner account knows what to assume.
        CfnOutput(
            self,
            "CrossAccountRoleArn",
            value=cross_account_role.role_arn,
            description="The ARN of the IAM role for the partner account to assume."
        )