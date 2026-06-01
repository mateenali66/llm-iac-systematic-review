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
    """CDK stack that provisions an S3 bucket suitable for CloudFront log delivery.

    The bucket is encrypted with a customer-managed KMS key, enforces SSL,
    blocks all public access, enables versioning, and transitions objects
    to Glacier after one year. Object Ownership is set to BUCKET_OWNER_PREFERRED
    and ACLs are enabled so the CloudFront log delivery service can write logs.
    """

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Customer-managed KMS key for bucket encryption.
        # NOTE: CloudFront standard (access) logs require AES256 or aws:kms with
        # an AWS-managed key. This key is suitable for CloudFront real-time logs
        # delivered via Kinesis or for general server access logs. Adjust as needed.
        log_key = kms.Key(
            self,
            "CloudFrontLogsKey",
            description="CMK for encrypting CloudFront log delivery S3 bucket",
            enable_key_rotation=True,
            removal_policy=RemovalPolicy.RETAIN,
            alias="alias/cloudfront-logs",
        )

        # Allow the CloudFront log delivery service to use the key.
        log_key.add_to_resource_policy(
            iam.PolicyStatement(
                sid="AllowCloudFrontLogDeliveryUseOfKey",
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

        # S3 bucket for CloudFront logs.
        self.logs_bucket = s3.Bucket(
            self,
            "CloudFrontLogsBucket",
            encryption=s3.BucketEncryption.KMS,
            encryption_key=log_key,
            bucket_key_enabled=True,
            enforce_ssl=True,
            versioned=True,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            # CloudFront log delivery uses ACLs to write to the bucket.
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
            ],
        )

        # Grant CloudFront log delivery service permission to write logs.
        self.logs_bucket.add_to_resource_policy(
            iam.PolicyStatement(
                sid="AWSLogDeliveryWrite",
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
                sid="AWSLogDeliveryAclCheck",
                effect=iam.Effect.ALLOW,
                principals=[iam.ServicePrincipal("delivery.logs.amazonaws.com")],
                actions=["s3:GetBucketAcl"],
                resources=[self.logs_bucket.bucket_arn],
                conditions={
                    "StringEquals": {"aws:SourceAccount": self.account}
                },
            )
        )