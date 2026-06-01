from aws_cdk import (
    aws_s3 as s3,
    aws_kms as kms,
    aws_cloudfront as cloudfront,
    aws_iam as iam,
    Stack,
    RemovalPolicy,
    Duration,
    CfnOutput,
)
from constructs import Construct

class CloudFrontLogBucketStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # KMS key for S3 bucket encryption
        log_bucket_key = kms.Key(
            self, "LogBucketKey",
            enable_key_rotation=True,
            description="KMS key for CloudFront log bucket encryption",
            policy=iam.PolicyDocument(
                statements=[
                    iam.PolicyStatement(
                        actions=["kms:*"],
                        principals=[iam.AccountRootPrincipal()],
                        resources=["*"],
                    ),
                    iam.PolicyStatement(
                        actions=[
                            "kms:Decrypt",
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
                    ),
                ]
            ),
        )

        # S3 bucket for CloudFront logs
        log_bucket = s3.Bucket(
            self, "CloudFrontLogBucket",
            encryption=s3.BucketEncryption.KMS,
            encryption_key=log_bucket_key,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            removal_policy=RemovalPolicy.RETAIN,
            versioned=True,
            lifecycle_rules=[
                s3.LifecycleRule(
                    id="GlacierTransition",
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

        # Bucket policy to allow CloudFront to write logs
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

        # Output the bucket name
        CfnOutput(
            self, "LogBucketName",
            value=log_bucket.bucket_name,
            description="Name of the S3 bucket for CloudFront logs",
        )

        CfnOutput(
            self, "LogBucketKeyArn",
            value=log_bucket_key.key_arn,
            description="ARN of the KMS key used for log bucket encryption",
        )