from aws_cdk import (
    Stack,
    RemovalPolicy,
    Duration,
    aws_s3 as s3,
    aws_kms as kms,
    aws_iam as iam
)
from constructs import Construct

class CloudFrontLogsBucketStack(Stack):
    def __init__(self, scope: Construct, construct_