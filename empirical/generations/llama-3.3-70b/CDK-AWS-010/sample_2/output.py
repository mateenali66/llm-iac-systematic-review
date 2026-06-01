import aws_cdk as cdk
from aws_cdk import aws_s3 as s3
from aws_cdk import aws_kms as kms
from aws_cdk import aws_iam as iam

class CloudFrontLogDeliveryStack(cdk.Stack):
    def __init__(self, scope: cdk.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        self.log_bucket = s3.Bucket(
            self, 'CloudFrontLogBucket',
            versioned=True,
            encryption=s3.BucketEncryption.KMS,
            encryption_key=kms.Key(
                self, 'LogBucketKey',
                alias='cloudfront-log-bucket-key',
                description='KMS key for CloudFront log bucket',
                enabled=True,
                enable_key_rotation=True
            )
        )

        self.log_bucket.add_lifecycle_rule(
            id='transition-to-glacier',
            enabled=True,
            noncurrent_version_transitions=[
                s3.NoncurrentVersionTransition(
                    storage_class=s3.StorageClass.GLACIER,
                    transition_after=cdk.Duration.days(365)
                )
            ],
            noncurrent_version_expiration=cdk.Duration.days(365)
        )

        self.log_bucket.add_to_resource_policy(
            policy_statement=iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=['s3:PutObject'],
                resources=[self.log_bucket.arn_for_objects('*')],
                principals=[iam.ServicePrincipal('cloudfront.amazonaws.com')]
            )
        )