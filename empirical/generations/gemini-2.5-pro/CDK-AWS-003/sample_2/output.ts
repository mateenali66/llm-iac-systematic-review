import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';

export class CustomerUploadsStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const customerUploadsBucket = new s3.Bucket(this, 'CustomerUploadsBucket', {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      versioned: true,
      lifecycleRules: [
        {
          id: 'DeleteOldObjects',
          enabled: true,
          expiration: cdk.Duration.days(365),
          transitions: [
            {
              storageClass: s3.StorageClass.INFREQUENT_ACCESS,
              transitionAfter: cdk.Duration.days(30),
            },
            {
              storageClass: s3.StorageClass.GLACIER,
              transitionAfter: cdk.Duration.days(90),
            },
          ],
        },
        {
            id: 'AbortIncompleteMultipartUploads',
            enabled: true,
            abortIncompleteMultipartUploadAfter: cdk.Duration.days(7),
        },
        {
            id: 'ExpireOldVersions',
            enabled: true,
            noncurrentVersionExpiration: cdk.Duration.days(30),
        }
      ],
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      autoDeleteObjects: false,
    });

    new cdk.CfnOutput(this, 'BucketName', {
        value: customerUploadsBucket.bucketName,
        description: 'The name of the customer uploads S3 bucket',
    });
  }
}