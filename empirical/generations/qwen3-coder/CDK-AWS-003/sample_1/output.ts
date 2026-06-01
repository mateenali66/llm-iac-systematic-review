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
      versioned: true,
      encryption: s3.BucketEncryption.S3_MANAGED,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      enforceSSL: true,
      lifecycleRules: [
        {
          expiration: cdk.Duration.days(365),
          id: 'DeleteAfter365Days',
          enabled: true,
        }
      ],
      serverAccessLogsPrefix: 'access-logs/',
    });

    // Bucket policy to restrict access
    customerFilesBucket.addToResourcePolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.DENY,
        actions: ['s3:*'],
        principals: [new iam.AnyPrincipal()],
        resources: [customerFilesBucket.bucketArn, customerFilesBucket.arnForObjects('*')],
        conditions: {
          Bool: { 'aws:SecureTransport': 'false' },
        },
      })
    );

    // Output bucket name
    new cdk.CfnOutput(this, 'CustomerFilesBucketName', {
      value: customerFilesBucket.bucketName,
      description: 'Name of the S3 bucket for customer files',
      exportName: 'CustomerFilesBucketName',
    });
  }
}