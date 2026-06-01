import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as iam from 'aws-cdk-lib/aws-iam';

export class CustomerUploadsStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const bucket = new s3.Bucket(this, 'CustomerUploadsBucket', {
      bucketName: `customer-uploads-${cdk.Aws.ACCOUNT_ID}-${cdk.Aws.REGION}`,
      encryption: s3.BucketEncryption.S3_MANAGED,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      versioned: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      autoDeleteObjects: false,
      enforceSSL: true,
      lifecycleRules: [
        {
          id: 'DeleteAfter365Days',
          enabled: true,
          expiration: cdk.Duration.days(365),
        },
      ],
    });

    bucket.addToResourcePolicy(
      new iam.PolicyStatement({
        sid: 'DenyInsecureTransport',
        effect: iam.Effect.DENY,
        principals: [new iam.AnyPrincipal()],
        actions: ['s3:*'],
        resources: [bucket.bucketArn, bucket.arnForObjects('*')],
        conditions: {
          Bool: { 'aws:SecureTransport': 'false' },
        },
      })
    );
  }
}