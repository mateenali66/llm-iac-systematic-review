import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as kms from 'aws-cdk-lib/aws-kms';
import { Construct } from 'constructs';

export interface CustomerUploadsBucketStackProps extends cdk.StackProps {
  readonly bucketName?: string;
  readonly expirationDays?: number;
  readonly noncurrentVersionExpirationDays?: number;
}

export class CustomerUploadsBucketStack extends cdk.Stack {
  public readonly bucket: s3.IBucket;
  public readonly encryptionKey: kms.IKey;

  constructor(scope: Construct, id: string, props: CustomerUploadsBucketStackProps = {}) {
    super(scope, id, props);

    const expirationDays = props.expirationDays ?? 365;
    const noncurrentVersionExpirationDays = props.noncurrentVersionExpirationDays ?? 30;

    const encryptionKey = new kms.Key(this, 'CustomerUploadsKmsKey', {
      description: 'CMK for customer uploads S3 bucket',
      enableKeyRotation: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      alias: 'alias/customer-uploads',
    });

    const accessLogsBucket = new s3.Bucket(this, 'CustomerUploadsAccessLogsBucket', {
      encryption: s3.BucketEncryption.S3_MANAGED,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      enforceSSL: true,
      versioned: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      objectOwnership: s3.ObjectOwnership.BUCKET_OWNER_ENFORCED,
      lifecycleRules: [
        {
          id: 'ExpireAccessLogs',
          enabled: true,
          expiration: cdk.Duration.days(365),
          abortIncompleteMultipartUploadAfter: cdk.Duration.days(7),
        },
      ],
    });

    const bucket = new s3.Bucket(this, 'CustomerUploadsBucket', {
      bucketName: props.bucketName,
      encryption: s3.BucketEncryption.KMS,
      encryptionKey,
      bucketKeyEnabled: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      enforceSSL: true,
      versioned: true,
      objectOwnership: s3.ObjectOwnership.BUCKET_OWNER_ENFORCED,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      serverAccessLogsBucket: accessLogsBucket,
      serverAccessLogsPrefix: 'customer-uploads/',
      eventBridgeEnabled: true,
      lifecycleRules: [
        {
          id: 'DeleteCurrentObjectsAfter365Days',
          enabled: true,
          expiration: cdk.Duration.days(expirationDays),
          abortIncompleteMultipartUploadAfter: cdk.Duration.days(7),
          transitions: [
            {
              storageClass: s3.StorageClass.INTELLIGENT_TIERING,
              transitionAfter: cdk.Duration.days(30),
            },
          ],
        },
        {
          id: 'ExpireNoncurrentVersions',
          enabled: true,
          noncurrentVersionExpiration: cdk.Duration.days(noncurrentVersionExpirationDays),
        },
      ],
    });

    this.bucket = bucket;
    this.encryptionKey = encryptionKey;

    new cdk.CfnOutput(this, 'CustomerUploadsBucketName', {
      value: bucket.bucketName,
      description: 'Name of the customer uploads S3 bucket',
      exportName: `${this.stackName}-BucketName`,
    });

    new cdk.CfnOutput(this, 'CustomerUploadsBucketArn', {
      value: bucket.bucketArn,
      description: 'ARN of the customer uploads S3 bucket',
      exportName: `${this.stackName}-BucketArn`,
    });

    new cdk.CfnOutput(this, 'CustomerUploadsKmsKeyArn', {
      value: encryptionKey.keyArn,
      description: 'ARN of the KMS key used for bucket encryption',
      exportName: `${this.stackName}-KmsKeyArn`,
    });
  }
}