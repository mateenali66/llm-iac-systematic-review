import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as kms from 'aws-cdk-lib/aws-kms';

export interface CustomerUploadsStackProps extends cdk.StackProps {
  /**
   * Optional explicit bucket name. If omitted, CloudFormation will generate one.
   */
  readonly bucketName?: string;

  /**
   * Number of days to retain customer-uploaded objects before deletion.
   * @default 365
   */
  readonly retentionDays?: number;

  /**
   * Number of days to retain non-current object versions before deletion.
   * @default 30
   */
  readonly noncurrentVersionRetentionDays?: number;
}

export class CustomerUploadsStack extends cdk.Stack {
  public readonly bucket: s3.IBucket;
  public readonly encryptionKey: kms.IKey;

  constructor(scope: Construct, id: string, props: CustomerUploadsStackProps = {}) {
    super(scope, id, props);

    const retentionDays = props.retentionDays ?? 365;
    const noncurrentRetentionDays = props.noncurrentVersionRetentionDays ?? 30;

    // Customer-managed KMS key for envelope encryption of uploaded files.
    const key = new kms.Key(this, 'CustomerUploadsKey', {
      description: 'CMK for encrypting customer-uploaded files in S3',
      enableKeyRotation: true,
      alias: 'alias/customer-uploads',
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      pendingWindow: cdk.Duration.days(30),
    });

    // Dedicated bucket for server access logs.
    const accessLogsBucket = new s3.Bucket(this, 'CustomerUploadsAccessLogs', {
      encryption: s3.BucketEncryption.S3_MANAGED,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      enforceSSL: true,
      versioned: false,
      objectOwnership: s3.ObjectOwnership.BUCKET_OWNER_PREFERRED,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      lifecycleRules: [
        {
          id: 'expire-access-logs',
          enabled: true,
          expiration: cdk.Duration.days(90),
          abortIncompleteMultipartUploadAfter: cdk.Duration.days(7),
        },
      ],
    });

    const bucket = new s3.Bucket(this, 'CustomerUploadsBucket', {
      bucketName: props.bucketName,
      encryption: s3.BucketEncryption.KMS,
      encryptionKey: key,
      bucketKeyEnabled: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      enforceSSL: true,
      versioned: true,
      objectOwnership: s3.ObjectOwnership.BUCKET_OWNER_ENFORCED,
      publicReadAccess: false,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      serverAccessLogsBucket: accessLogsBucket,
      serverAccessLogsPrefix: 'customer-uploads/',
      lifecycleRules: [
        {
          id: 'expire-customer-uploads',
          enabled: true,
          expiration: cdk.Duration.days(retentionDays),
          noncurrentVersionExpiration: cdk.Duration.days(noncurrentRetentionDays),
          abortIncompleteMultipartUploadAfter: cdk.Duration.days(7),
          transitions: [
            {
              storageClass: s3.StorageClass.INTELLIGENT_TIERING,
              transitionAfter: cdk.Duration.days(30),
            },
          ],
        },
        {
          id: 'expire-delete-markers',
          enabled: true,
          expiredObjectDeleteMarker: true,
        },
      ],
    });

    // Deny any non-TLS access (defense in depth alongside enforceSSL).
    bucket.addToResourcePolicy(
      new cdk.aws_iam.PolicyStatement({
        sid: 'DenyInsecureTransport',
        effect: cdk.aws_iam.Effect.DENY,
        principals: [new cdk.aws_iam.AnyPrincipal()],
        actions: ['s3:*'],
        resources: [bucket.bucketArn, bucket.arnForObjects('*')],
        conditions: { Bool: { 'aws:SecureTransport': 'false' } },
      }),
    );

    // Deny uploads that are not encrypted with our KMS CMK.
    bucket.addToResourcePolicy(
      new cdk.aws_iam.PolicyStatement({
        sid: 'DenyUnEncryptedObjectUploads',
        effect: cdk.aws_iam.Effect.DENY,
        principals: [new cdk.aws_iam.AnyPrincipal()],
        actions: ['s3:PutObject'],
        resources: [bucket.arnForObjects('*')],
        conditions: {
          StringNotEquals: { 's3:x-amz-server-side-encryption': 'aws:kms' },
        },
      }),
    );

    bucket.addToResourcePolicy(
      new cdk.aws_iam.PolicyStatement({
        sid: 'DenyWrongKmsKey',
        effect: cdk.aws_iam.Effect.DENY,
        principals: [new cdk.aws_iam.AnyPrincipal()],
        actions: ['s3:PutObject'],
        resources: [bucket.arnForObjects('*')],
        conditions: {
          StringNotEqualsIfExists: {
            's3:x-amz-server-