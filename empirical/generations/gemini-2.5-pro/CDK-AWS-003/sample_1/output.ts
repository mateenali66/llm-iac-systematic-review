import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';

export class CustomerUploadsStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const serverAccessLogsBucket = new s3.Bucket(this, 'ServerAccessLogsBucket', {
      objectOwnership: s3.ObjectOwnership.OBJECT_WRITER,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      versioned: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      lifecycleRules: [
        {
          id: 'ExpireOldLogs',
          enabled: true,
          expiration: cdk.Duration.days(90),
        },
      ],
    });

    const customerUploadsBucket = new s3.Bucket(this, 'CustomerUploadsBucket', {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      versioned: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      serverAccessLogsBucket: serverAccessLogsBucket,
      serverAccessLogsPrefix: 'uploads-access-logs/',
      lifecycleRules: [
        {
          id: 'DeleteAfter365Days',
          enabled: true,
          expiration: cdk.Duration.days(365),
        },
        {
          id: 'AbortIncompleteMultipartUploads',
          enabled: true,
          abortIncompleteMultipartUploadAfter: cdk.Duration.days(7),
        },
      ],
    });

    new cdk.CfnOutput(this, 'CustomerUploadsBucketName', {
      value: customerUploadsBucket.bucketName,
      description: 'The name of the S3 bucket for customer uploads.',
      exportName: 'CustomerUploadsBucketName',
    });
  }
}