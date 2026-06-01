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
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create KMS key for encryption
        log_bucket_key = kms.Key(
            self, "CloudFrontLogBucketKey",
            enable_key_rotation=True,
            description="KMS key for CloudFront log bucket encryption"
        )

        # Create S3 bucket for CloudFront logs
        log_bucket = s3.Bucket(
            self, "CloudFrontLogBucket",
            encryption=s3.BucketEncryption.KMS,
            encryption_key=log_bucket_key,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            enforce_ssl=True,
            versioned=True,
            removal_policy=RemovalPolicy.RETAIN,
            lifecycle_rules=[
                s3.LifecycleRule(
                    id="TransitionToGlacier",
                    transitions=[
                        s3.Transition(
                            storage_class=s3.StorageClass.GLACIER,
                            transition_after=Duration.days(365)
                        )
                    ]
                )
            ]
        )

        # Add bucket policy for CloudFront log delivery
        log_bucket.add_to_resource_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                principals=[iam.ServicePrincipal("delivery.logs.amazonaws.com")],
                actions=["s3:PutObject"],
                resources=[f"{log_bucket.bucket_arn}/*"],
                conditions={
                    "StringEquals": {
                        "s3:x-amz-acl": "bucket-owner-full-control"
                    }
                }
            )
        )

        log_bucket.add_to_resource_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                principals=[iam.ServicePrincipal("delivery.logs.amazonaws.com")],
                actions=["s3:GetBucketAcl"],
                resources=[log_bucket.bucket_arn]
            )
        )