from aws_cdk import (
    Stack,
    RemovalPolicy,
    Duration,
    aws_s3 as s3,
    aws_kms as kms,
)
from constructs import Construct


class CloudFrontLogsStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        kms_key = kms.Key(
            self,
            "CloudFrontLogsKey",
            description="KMS key for CloudFront access logs bucket",
            enable_key_rotation=True,
            removal_policy=RemovalPolicy.RETAIN,
        )

        s3.Bucket(
            self,
            "CloudFrontLogsBucket",
            bucket_name=None,
            encryption=s3.BucketEncryption.KMS,
            encryption_key=kms_key,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            enforce_ssl=True,
            versioned=False,
            removal_policy=RemovalPolicy.RETAIN,
            object_ownership=s3.ObjectOwnership.BUCKET_OWNER_PREFERRED,
            lifecycle_rules=[
                s3.LifecycleRule(
                    id="TransitionToGlacier",
                    enabled=True,
                    transitions=[
                        s3.Transition(
                            storage_class=s3.StorageClass.GLACIER,
                            transition_after=Duration.days(365),
                        )
                    ],
                )
            ],
        )