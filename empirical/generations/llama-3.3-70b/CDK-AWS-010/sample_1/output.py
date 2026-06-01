import aws_cdk as cdk
from aws_cdk import aws_s3 as s3
from aws_cdk import aws_kms as kms
from aws_cdk import aws_iam as iam

class CloudFrontLogDeliveryStack(cdk.Stack):

    def __init__(self, scope: cdk.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        self.log_delivery_bucket = s3.Bucket(
            self, 'LogDeliveryBucket',
            versioned=True,
            encryption=s3.BucketEncryption.KMS,
            encryption_key=kms.Key(
                self, 'LogDeliveryKey',
                description='Key for CloudFront log delivery bucket',
                alias='alias/cloudfront-log-delivery-key'
            )
        )

        self.log_delivery_bucket.add_to_resource_policy(
            policy_statement=iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                principals=[iam.ServicePrincipal('cloudfront.amazonaws.com')],
                actions=['s3:PutObject'],
                resources=[self.log_delivery_bucket.arn_for_objects('*')]
            )
        )

        self.log_delivery_bucket.add_lifecycle_rule(
            enabled=True,
            expiration=cdk.Duration.days(365),
            storage_class=s3.StorageClass.GLACIER
        )

        cdk.CfnOutput(
            self, 'LogDeliveryBucketName',
            value=self.log_delivery_bucket.bucket_name,
            description='Name of the S3 bucket for CloudFront log delivery'
        )