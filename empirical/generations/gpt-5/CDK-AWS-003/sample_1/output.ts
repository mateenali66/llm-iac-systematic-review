import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';

export class CustomerUploadsStack extends cdk.Stack {
  public readonly bucket: s3.Bucket;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const accessLogsBucket = new s3.Bucket(this, 'AccessLogsBucket', {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      objectOwnership: s3.ObjectOwnership.BUCKET_OWNER_ENFORCED,
      versioned: true,
      lifecycleRules: [
        {
          expiration: cdk.Duration.days(365),
          noncurrentVersionExpiration: cdk.Duration.days(180),
          abortIncompleteMultipartUploadAfter: cdk.Duration.days(7),
        },
      ],
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    this.bucket = new s3.Bucket(this, 'CustomerUploadsBucket', {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      objectOwnership: s3.ObjectOwnership.BUCKET_OWNER_ENFORCED,
      versioned: true,
      lifecycleRules: [
        {
          expiration: cdk.Duration.days(365),
          noncurrentVersionExpiration: cdk.Duration.days(365),
          abortIncompleteMultipartUploadAfter: cdk.Duration.days(7),
        },
      ],
      serverAccessLogsBucket: accessLogsBucket,
      serverAccessLogsPrefix: 's3-access-logs/',
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });
  }
}