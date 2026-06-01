from aws_cdk import (
    Duration,
    RemovalPolicy,
    Stack,
    aws_iam as iam,
    aws_kms as kms,
    aws_s3 as s3,
)
from constructs import Construct


class CloudFrontLogBucketStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        kms_key = kms.Key(
            self,
            "CloudFrontLogKmsKey",
            enable_key_rotation=True,
            removal_policy=RemovalPolicy.RETAIN,
        )

        bucket = s3.Bucket(
            self,
            "CloudFrontLogBucket",
            bucket_name=None,
            encryption=s3.BucketEncryption.KMS,
            encryption_key=kms_key,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            object_ownership=s3.ObjectOwnership.BUCKET_OWNER_ENFORCED,
            enforce_ssl=True,
            versioned=False,
            removal_policy=RemovalPolicy.RETAIN,
            lifecycle_rules=[
                s3.LifecycleRule(
                    id="TransitionToGlacierAfter1Year",
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

        # Allow CloudFront to deliver logs (canonical ID for ACL-less bucket)
        bucket.add_to_resource_policy(
            iam.PolicyStatement(
                sid="AllowCloudFrontLogDelivery",
                effect=iam.Effect.ALLOW,
                principals=[iam.ServicePrincipal("cloudfront.amazonaws.com")],
                actions=["s3:PutObject"],
                resources=[bucket.arn_for_objects("*")],
                conditions={
                    "StringEquals": {
                        "aws:SourceAccount": self.account
                    }
                },
            )
        )