from aws_cdk import (
    Stack,
    Duration,
    RemovalPolicy,
    aws_s3 as s3,
    aws_kms as kms,
    aws_iam as iam,
)
from constructs import Construct


class CloudFrontLogsBucketStack(Stack):
    """CDK stack that provisions an S3 bucket for CloudFront log delivery.

    The bucket is encrypted with a customer-managed KMS key, blocks all public
    access, enforces TLS in transit, and transitions objects to Glacier after
    one year. Object ownership is set to BUCKET_OWNER_PREFERRED with ACLs
    enabled, which is required for CloudFront standard log delivery.
    """

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Customer-managed KMS key for bucket encryption.
        # Note: CloudFront standard (access) logs only support SSE-S3 on the
        # destination bucket. This key is suitable for CloudFront *real-time*
        # logs (delivered via Kinesis) or for CloudFront standard logs only if
        # you use a CloudFront log delivery v2 destination. For the classic
        # standard logging path, switch encryption to S3_MANAGED.
        self.log_encryption_key = kms.Key(
            self,
            "CloudFrontLogsKey",
            description="CMK used to encrypt the CloudFront logs S3 bucket",
            enable_key_rotation=True,
            removal_policy=RemovalPolicy.RETAIN,
            alias="alias/cloudfront-logs",
        )

        # Allow the CloudFront log delivery service principal to use the key.
        self.log_encryption_key.add_to_resource_policy(
            iam.PolicyStatement(
                sid="AllowCloudFrontLogDeliveryUseOfTheKey",
                effect=iam.Effect.ALLOW,
                principals=[iam.ServicePrincipal("delivery.logs.amazonaws.com")],
                actions=[
                    "kms:Encrypt",
                    "kms:Decrypt",
                    "kms:ReEncrypt*",
                    "kms:GenerateDataKey*",
                    "kms:DescribeKey",
                ],
                resources=["*"],
            )
        )

        # S3 bucket for CloudFront log delivery.
        self.logs_bucket = s3.Bucket(
            self,
            "CloudFrontLogsBucket",
            encryption=s3.BucketEncryption.KMS,
            encryption_key=self.log_encryption_key,
            bucket_key_enabled=True,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            enforce_ssl=True,
            versioned=True,
            # CloudFront log delivery requires ACLs. BUCKET_OWNER_PREFERRED
            # ensures objects written by the log delivery service are owned
            # by this account.
            object_ownership=s3.ObjectOwnership.BUCKET_OWNER_PREFERRED,
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
                    noncurrent_version_transitions=[
                        s3.NoncurrentVersionTransition(
                            storage_class=s3.StorageClass.GLACIER,
                            transition_after=Duration.days(365),
                        )
                    ],
                    abort_incomplete_multipart_upload_after=Duration.days(7),
                ),
                s3.LifecycleRule(
                    id="ExpireNoncurrentVersions",
                    enabled=True,
                    noncurrent_version_expiration=Duration.days(2555),
                ),
            ],
        )

        # Grant the CloudFront log delivery service permission to write logs.
        self.logs_bucket.add_to_resource_policy(
            iam.PolicyStatement(
                sid="AllowCloudFrontLogDeliveryWrite",
                effect=iam.Effect.ALLOW,
                principals=[iam.ServicePrincipal("delivery.logs.amazonaws.com")],
                actions=["s3:PutObject"],
                resources=[self.logs_bucket.arn_for_objects("*")],
                conditions={
                    "StringEquals": {
                        "s3:x-amz-acl": "bucket-owner-full-control",
                        "aws:SourceAccount": self.account,
                    }
                },
            )
        )

        self.logs_bucket.add_to_resource_policy(
            iam.PolicyStatement(
                sid="AllowCloudFrontLogDeliveryAclCheck",
                effect=iam.Effect.ALLOW,
                principals=[iam.ServicePrincipal("delivery.logs.amazonaws.com")],
                actions=["s3:GetBucketAcl"],
                resources=[self.logs_bucket.bucket_arn],
                conditions={
                    "StringEquals": {"aws:SourceAccount": self.account}
                },
            )
        )