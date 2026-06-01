from aws_cdk import (
    App,
    Stack,
    Duration,
    RemovalPolicy,
    CfnOutput,
)
from aws_cdk import aws_s3 as s3
from aws_cdk import aws_kms as kms
from aws_cdk import aws_iam as iam
from constructs import Construct


class CloudFrontLogsBucketStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        key = kms.Key(
            self,
            "LogsBucketKmsKey",
            enable_key_rotation=True,
            alias="alias/cloudfront-logs-bucket",
            description="KMS key for encrypting CloudFront access logs in S3",
        )
        key.apply_removal_policy(RemovalPolicy.RETAIN)

        bucket = s3.Bucket(
            self,
            "CloudFrontLogsBucket",
            versioned=True,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            encryption=s3.BucketEncryption.KMS,
            encryption_key=key,
            bucket_key_enabled=True,
            enforce_ssl=True,
            object_ownership=s3.ObjectOwnership.BUCKET_OWNER_PREFERRED,
            access_control=s3.BucketAccessControl.LOG_DELIVERY_WRITE,
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
        bucket.apply_removal_policy(RemovalPolicy.RETAIN)

        bucket.add_to_resource_policy(
            iam.PolicyStatement(
                sid="DenyInsecureTransport",
                effect=iam.Effect.DENY,
                principals=[iam.AnyPrincipal()],
                actions=["s3:*"],
                resources=[bucket.bucket_arn, f"{bucket.bucket_arn}/*"],
                conditions={"Bool": {"aws:SecureTransport": "false"}},
            )
        )

        CfnOutput(self, "LogsBucketName", value=bucket.bucket_name)
        CfnOutput(self, "KmsKeyArn", value=key.key_arn)


app = App()
CloudFrontLogsBucketStack(app, "CloudFrontLogsBucketStack")
app.synth()