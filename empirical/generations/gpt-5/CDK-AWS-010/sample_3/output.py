from aws_cdk import (
    Aws,
    Duration,
    RemovalPolicy,
    Stack,
    aws_iam as iam,
    aws_kms as kms,
    aws_s3 as s3,
)
from constructs import Construct


class CloudFrontLogsBucketStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        kms_key = kms.Key(
            self,
            "LogsKmsKey",
            enable_key_rotation=True,
            alias="alias/cloudfront-logs",
        )

        logs_bucket = s3.Bucket(
            self,
            "CloudFrontLogsBucket",
            encryption=s3.BucketEncryption.KMS,
            encryption_key=kms_key,
            bucket_key_enabled=True,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            object_ownership=s3.ObjectOwnership.BUCKET_OWNER_PREFERRED,
            enforce_ssl=True,
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
            auto_delete_objects=False,
        )

        kms_key.add_to_resource_policy(
            iam.PolicyStatement(
                sid="AllowS3UseOfKMSForDefaultEncryption",
                effect=iam.Effect.ALLOW,
                principals=[iam.ServicePrincipal("s3.amazonaws.com")],
                actions=[
                    "kms:Encrypt",
                    "kms:Decrypt",
                    "kms:ReEncrypt*",
                    "kms:GenerateDataKey*",
                    "kms:DescribeKey",
                ],
                resources=["*"],
                conditions={
                    "StringEquals": {"aws:SourceAccount": Aws.ACCOUNT_ID},
                    "ArnLike": {"aws:SourceArn": logs_bucket.bucket_arn},
                },
            )
        )

        logs_bucket.add_to_resource_policy(
            iam.PolicyStatement(
                sid="AllowCloudFrontLogging",
                effect=iam.Effect.ALLOW,
                principals=[iam.ServicePrincipal("delivery.logs.amazonaws.com")],
                actions=["s3:PutObject"],
                resources=[f"{logs_bucket.bucket_arn}/*"],
                conditions={"StringEquals": {"s3:x-amz-acl": "bucket-owner-full-control"}},
            )
        )

        logs_bucket.add_to_resource_policy(
            iam.PolicyStatement(
                sid="AllowCloudFrontGetBucketACL",
                effect=iam.Effect.ALLOW,
                principals=[iam.ServicePrincipal("delivery.logs.amazonaws.com")],
                actions=["s3:GetBucketAcl"],
                resources=[logs_bucket.bucket_arn],
            )
        )