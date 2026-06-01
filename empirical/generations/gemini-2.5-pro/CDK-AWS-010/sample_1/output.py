from aws_cdk import (
    Stack,
    RemovalPolicy,
    Duration,
    CfnOutput,
    aws_s3 as s3,
    aws_kms as kms,
    aws_iam as iam,
)
from constructs import Construct


class CloudfrontLogBucketStack(Stack):
    """
    A CDK stack that provisions a secure