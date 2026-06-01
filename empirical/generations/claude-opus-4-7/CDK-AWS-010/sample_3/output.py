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
    """CDK Stack provisioning an S3 bucket for CloudFront log delivery.

    The bucket is encrypted with a customer-managed KMS key, blocks all
    public access, enforces TLS, has access logging enabled (via a separate
    server access logs bucket), and transitions objects to Glacier after
    365 days.
    """

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # ----------------------------------------------------------------- #
        # KMS Customer Managed Key for S3 SSE-KMS encryption
        # ----------------------------------------------------------------- #
        kms_key = kms.Key(
            self,
            "CloudFrontLogsKmsKey",
            description="CMK used to encrypt CloudFront access logs in S3",
            enable_key_rotation=True,
            removal_policy=RemovalPolicy.RETAIN,
            alias="alias/cloudfront-logs-key",
        )

        # CloudFront log delivery uses the AWS managed account
        # 'awslogsdelivery' (canonical user id is set automatically by S3
        # ACLs). For SSE-KMS, the CloudFront log delivery service principal
        # 'delivery.logs.amazonaws.com' must be allowed to use the key.
        kms_key.add_to_resource_policy(
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
                conditions={
                    "StringEquals": {
                        "aws:SourceAccount": self.account,
                    }
                },
            )
        )

        # ----------------------------------------------------------------- #
        # Server access logs bucket (for the CloudFront logs bucket itself)
        # ----------------------------------------------------------------- #
        access_logs_bucket = s3.Bucket(
            self,
            "CloudFrontLogsAccessLogsBucket",
            encryption=s3.BucketEncryption.S3_MANAGED,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            enforce_ssl=True,
            versioned=True,
            object_ownership=s3.ObjectOwnership.BUCKET_OWNER_PREFERRED,
            removal_policy=RemovalPolicy.RETAIN,
            lifecycle_rules=[
                s3.LifecycleRule(
                    id="ExpireOldAccessLogs",
                    enabled=True,
                    expiration=Duration.days(365),
                    abort_incomplete_multipart_upload_after=Duration.days(7),
                )
            ],
        )

        # ----------------------------------------------------------------- #
        # CloudFront log delivery bucket
        # ----------------------------------------------------------------- #
        # CloudFront (standard logs) requires ACLs on the destination bucket
        # to grant FULL_CONTROL to the 'awslogsdelivery' canonical user.
        # Therefore Object Ownership must allow ACLs (ObjectWriter).
        self.logs_bucket = s3.Bucket(
            self,
            "CloudFrontLogsBucket",
            encryption=s3.BucketEncryption.KMS,
            encryption_key=kms_key,
            bucket_key_enabled=True,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            enforce_ssl=True,
            versioned=True,
            # CloudFront standard logging requires ACL writes for the
            # log delivery group; ObjectWriter retains writer ownership.
            object_ownership=s3.ObjectOwnership.OBJECT_WRITER,
            server_access_logs_bucket=access_logs_bucket,
            server_access_logs_prefix="s3-access/",
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
                )
            ],
        )

        # Explicit bucket policy: deny unencrypted uploads and require
        # SSE-KMS using our CMK for any PutObject operation.
        self.logs_bucket.add_to_resource_policy(
            iam.PolicyStatement(
                sid="DenyUnEncryptedObjectUploads",
                effect=iam.Effect.DENY,
                principals=[iam.AnyPrincipal()],
                actions=["s3:PutObject"],
                resources=[self.logs_bucket.arn_for_objects("*")],
                conditions={
                    "StringNotEquals": {
                        "s3:x-amz-server-side-encryption": "aws:kms"
                    }
                },