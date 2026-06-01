from aws_cdk import (
    Stack,
    aws_s3 as s3,
    aws_kms as kms,
    Duration,
    aws_iam as iam,
)
from constructs import Construct

class CloudFrontLogBucketStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        kms_key = kms.Key(
            self,
            "CloudFrontLogKmsKey",
            enable_key_rotation=True,
            description="KMS key for CloudFront S3 log encryption",
        )

        bucket = s3.Bucket(
            self,
            "CloudFrontLogsBucket",
            encryption=s3.BucketEncryption.KMS,
            encryption_key=kms_key,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            enforce_ssl=True,
            versioned=False,
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

        bucket.add_to_resource_policy(
            iam.PolicyStatement(
                sid="AllowCloudFrontLogDelivery",
                effect=iam.Effect.ALLOW,
                principals=[iam.ServicePrincipal("cloudfront.amazonaws.com")],
                actions=["s3:PutObject"],
                resources=[bucket.arn_for_objects("*")],
            )
        )