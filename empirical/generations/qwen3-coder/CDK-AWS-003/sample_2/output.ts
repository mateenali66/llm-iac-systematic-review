import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export class CustomerFilesStorageStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Create S3 bucket for customer uploaded files
    const customerFilesBucket = new s3.Bucket(this, 'CustomerFilesBucket', {
      bucketName: `customer-files-${this.account}-${this.region}`,
      encryption: s3.BucketEncryption.S3_MANAGED,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      versioned: true,
      enforceSSL: true,
      lifecycleRules: [
        {
          expiration: cdk.Duration.days(365),
          id: 'DeleteAfter365Days',
          enabled: true
        }
      ]
    });

    // Create IAM policy for application access
    const bucketAccessPolicy = new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        's3:GetObject',
        's3:PutObject',
        's3:DeleteObject',
        's3:ListBucket'
      ],
      resources: [
        customerFilesBucket.bucketArn,
        `${customerFilesBucket.bucketArn}/*`
      ]
    });

    // Output bucket name
    new cdk.CfnOutput(this, 'CustomerFilesBucketName', {
      value: customerFilesBucket.bucketName,
      description: 'Name of the S3 bucket for customer files',
      exportName: 'CustomerFilesBucketName'
    });

    // Output bucket ARN
    new cdk.CfnOutput(this, 'CustomerFilesBucketArn', {
      value: customerFilesBucket.bucketArn,
      description: 'ARN of the S3 bucket for customer files',
      exportName: 'CustomerFilesBucketArn'
    });
  }
}