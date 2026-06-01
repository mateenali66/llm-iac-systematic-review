from aws_cdk import (
    Stack,
    Duration,
    RemovalPolicy,
    aws_s3 as s3,
)
from constructs import Construct


class CloudFrontLogBucketStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        s3.Bucket(
            self,
            "CloudFrontAccessLogs",
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            encryption=s3.BucketEncryption.KMS_MANAGED,
            bucket_key_enabled=True,
            enforce_ssl=True,
            object_ownership=s3.ObjectOwnership.BUCKET_OWNER_PREFERRED,
            access_control=s3.BucketAccessControl.LOG_DELIVERY_WRITE,
            versioned=False,
            lifecycle_rules=[
                s3.LifecycleRule(
                    transitions=[
                        s3.Transition(
                            storage_class=s3.StorageClass.GLACIER,
                            transition_after=Duration.days(365),
                        )
                    ]
                )
            ],
            removal_policy=RemovalPolicy.RETAIN,
        )