from aws_cdk import (
    aws_s3 as s3,
    aws_kms as kms,
    aws_cloudfront as cloudfront,
    aws_iam as iam,
    Duration,
    RemovalPolicy,
    Stack,
    CfnOutput,
)
from constructs import Construct


class CloudFrontLogBucketStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # KMS key for S3 bucket encryption
        log_bucket_key = kms.Key(
            self,
            "LogBucketKey",
            description="KMS key for CloudFront log delivery bucket",
            enable_key_rotation=True,
            pending_window=Duration.days(7),
            removal_policy=RemovalPolicy.DESTROY,
        )

        # S3 bucket for CloudFront logs
        log_bucket = s3.Bucket(
            self,
            "CloudFrontLogBucket",
            encryption=s3.BucketEncryption.KMS,
            encryption_key=log_bucket_key,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            removal_policy=RemovalPolicy.DESTROY,
            auto_delete_objects=True,
            enforce_ssl=True,
            versioned=False,
            lifecycle_rules=[
                s3.LifecycleRule(
                    id="GlacierTransition",
                    transitions=[
                        s3.Transition(
                            storage_class=s3.StorageClass.GLACIER,
                            transition_after=Duration.days(365),
                        )
                    ],
                    enabled=True,
                )
            ],
        )

        # Grant CloudFront service principal write access to the bucket
        log_bucket.add_to_resource_policy(
            iam.PolicyStatement(
                actions=["s3:PutObject"],
                principals=[
                    iam.ServicePrincipal("cloudfront.amazonaws.com")
                ],
                resources=[log_bucket.arn_for_objects("*")],
                conditions={
                    "StringEquals": {
                        "AWS:SourceArn": f"arn:aws:cloudfront::{self.account}:distribution/*"
                    }
                },
            )
        )

        # Grant CloudFront service principal access to the KMS key
        log_bucket_key.add_to_resource_policy(
            iam.PolicyStatement(
                actions=[
                    "kms:Decrypt",
                    "kms:Encrypt",
                    "kms:GenerateDataKey",
                ],
                principals=[
                    iam.ServicePrincipal("cloudfront.amazonaws.com")
                ],
                resources=["*"],
                conditions={
                    "StringEquals": {
                        "AWS:SourceArn": f"arn:aws:cloudfront::{self.account}:distribution/*"
                    }
                },
            )
        )

        # Output the bucket name
        CfnOutput(
            self,
            "LogBucketName",
            value=log_bucket.bucket_name,
            description="Name of the S3 bucket for CloudFront logs",
        )

        CfnOutput(
            self,
            "LogBucketKeyArn",
            value=log_bucket_key.key_arn,
            description="ARN of the KMS key used for log bucket encryption",
        )