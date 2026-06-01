import { Stack, StackProps, Duration, RemovalPolicy, CfnOutput } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import {
  Bucket,
  BucketEncryption,
  BlockPublicAccess,
  ObjectOwnership,
  BucketAccessControl,
} from 'aws-cdk-lib/aws-s3';

export class CustomerUploadsBucketStack extends Stack {
  public readonly bucket: Bucket;

  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const accessLogsBucket = new Bucket(this, 'AccessLogsBucket', {
      enforceSSL: true,
      encryption: BucketEncryption.S3_MANAGED,
      blockPublicAccess: BlockPublicAccess.BLOCK_ALL,
      objectOwnership: ObjectOwnership.OBJECT_WRITER,
      accessControl: BucketAccessControl.LOG_DELIVERY_WRITE,
      lifecycleRules: [
        {
          expiration: Duration.days(365),
          abortIncompleteMultipartUploadAfter: Duration.days(7),
        },
      ],
      removalPolicy: RemovalPolicy.RETAIN,
    });

    this.bucket = new Bucket(this, 'CustomerUploadsBucket', {
      versioned: true,
      encryption: BucketEncryption.KMS_MANAGED,
      bucketKeyEnabled: true,
      blockPublicAccess: BlockPublicAccess.BLOCK_ALL,
      objectOwnership: ObjectOwnership.BUCKET_OWNER_ENFORCED,
      enforceSSL: true,
      serverAccessLogsBucket: accessLogsBucket,
      serverAccessLogsPrefix: 's3-access-logs/',
      lifecycleRules: [
        {
          expiration: Duration.days(365),
          noncurrentVersionExpiration: Duration.days(365),
          abortIncompleteMultipartUploadAfter: Duration.days(7),
        },
      ],
      removalPolicy: RemovalPolicy.RETAIN,
    });

    new CfnOutput(this, 'CustomerUploadsBucketName', {
      value: this.bucket.bucketName,
      exportName: 'CustomerUploadsBucketName',
    });
  }
}