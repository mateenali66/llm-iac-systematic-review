import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';

export class CustomerFilesStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const bucket = new s3.Bucket(this, 'CustomerFilesBucket', {
      versioned: true,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
    });

    bucket.addLifecycleRule({
      enabled: true,
      expiration: cdk.Duration.days(365),
    });

    new cdk.CfnOutput(this, 'CustomerFilesBucketName', {
      value: bucket.bucketName,
      description: 'The name of the S3 bucket for customer files',
    });
  }
}