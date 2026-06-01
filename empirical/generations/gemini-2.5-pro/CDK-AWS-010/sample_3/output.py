import aws_cdk as cdk
from aws_cdk import (
    Stack,
    aws_s3 as s3,
    aws_kms as kms,
    aws_iam as iam,
    RemovalPolicy,
    Duration
)
from constructs import Construct

class CloudFrontLogBucketStack(Stack):
    def __init__(self,