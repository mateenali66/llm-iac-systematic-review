import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as kms from 'aws-cdk-lib/aws-kms';
import { Construct } from 'constructs';

export interface CustomerUploadsStackProps extends cdk.StackProps {
  /**
   * Number of days after which objects (and noncurrent versions) are permanently deleted.
   * @default 365
   */
  readonly expirationDays?: number;

  /**
   * Optional explicit bucket name. If omitted, CloudFormation will generate one.
   */
  readonly bucketName?: string;
}

export class CustomerUploadsStack extends cdk.Stack {
  public readonly bucket: s3.Bucket;
  public readonly encryptionKey: kms.Key;

  constructor(scope: Construct, id: string, props: CustomerUploadsStackProps = {}) {
    super(scope, id, props);

    const expirationDays = props.expirationDays ?? 365;

    this.encryptionKey = new kms.Key(this, 'CustomerUploadsKey', {
      description: 'CMK for encrypting customer-uploaded files in S3',
      enableKeyRotation: true,
      alias: 'alias/customer-uploads',
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      pendingWindow: cdk.Duration.days(30),
    });

    this.bucket = new s3.Bucket(this, 'CustomerUploadsBucket', {
      bucketName: props.bucketName,
      encryption: s3.BucketEncryption.KMS,
      encryptionKey: this.encryptionKey,
      bucketKeyEnabled: true,
      enforceSSL: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      publicReadAccess: false,
      versioned: true,
      objectOwnership: s3.ObjectOwnership.BUCKET_OWNER_ENFORCED,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      autoDeleteObjects: false,
      serverAccessLogsPrefix: 'access-logs/',
      eventBridgeEnabled: true,
      lifecycleRules: [
        {
          id: 'ExpireCurrentObjectsAfter365Days',
          enabled: true,
          expiration: cdk.Duration.days(expirationDays),
          noncurrentVersionExpiration: cdk.Duration.days(expirationDays),
          abortIncompleteMultipartUploadAfter: cdk.Duration.days(7),
          expiredObjectDeleteMarker: true,
        },
        {
          id: 'TransitionToInfrequentAccess',
          enabled: true,
          transitions: [
            {
              storageClass: s3.StorageClass.INTELLIGENT_TIERING,
              transitionAfter: cdk.Duration.days(30),
            },
          ],
          noncurrentVersionTransitions: [
            {
              storageClass: s3.StorageClass.GLACIER_INSTANT_RETRIEVAL,
              transitionAfter: cdk.Duration.days(30),
            },
          ],
        },
      ],
    });

    cdk.Tags.of(this.bucket).add('DataClassification', 'Confidential');
    cdk.Tags.of(this.bucket).add('Purpose', 'CustomerUploads');

    new cdk.CfnOutput(this, 'CustomerUploadsBucketName', {
      value: this.bucket.bucketName,
      description: 'Name of the customer uploads S3 bucket',
      exportName: `${this.stackName}-BucketName`,
    });

    new cdk.CfnOutput(this, 'CustomerUploadsBucketArn', {
      value: this.bucket.bucketArn,
      description: 'ARN of the customer uploads S3 bucket',
      exportName: `${this.stackName}-BucketArn`,
    });

    new cdk.CfnOutput(this, 'CustomerUploadsKmsKeyArn', {
      value: this.encryptionKey.keyArn,
      description: 'ARN of the KMS key used to encrypt customer uploads',
      exportName: `${this.stackName}-KmsKeyArn`,
    });
  }
}