import os
from aws_cdk import (
    App,
    Stack,
    Environment,
    CfnParameter,
    CfnOutput,
    aws_iam as iam
)
from constructs import Construct

class CrossAccountLambdaRoleStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **