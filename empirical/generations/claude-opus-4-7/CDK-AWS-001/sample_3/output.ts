import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as logs from 'aws-cdk-lib/aws-logs';
import { NodejsFunction, NodejsFunctionProps } from 'aws-cdk-lib/aws-lambda-nodejs';
import * as path from 'path';

export interface ItemsCatalogStackProps extends cdk.StackProps {
  readonly stageName?: string;
}

export class ItemsCatalogStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: ItemsCatalogStackProps = {}) {
    super(scope, id, props);

    const stageName = props.stageName ?? 'prod';

    const table = new dynamodb.Table(this, 'ItemsTable', {
      tableName: `items-catalog-${stageName}`,
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
      pointInTimeRecovery: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      deletionProtection: true,
      contributorInsightsEnabled: true,
    });

    const commonLambdaProps: NodejsFunctionProps = {
      runtime: lambda.Runtime.NODEJS_20_X,
      architecture: lambda.Architecture.ARM_64,
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      tracing: lambda.Tracing.ACTIVE,
      logRetention: logs.RetentionDays.ONE_MONTH,
      environment: {
        TABLE_NAME: table.tableName,
        NODE_OPTIONS: '--enable-source-maps',
        POWERTOOLS_SERVICE_NAME: 'items-catalog',
        LOG_LEVEL: 'INFO',
      },
      bundling: {
        minify: true,
        sourceMap: true,
        target: 'node20',
        externalModules: ['@aws-sdk/*'],
      },
    };

    const getItemFn = new NodejsFunction(this, 'GetItemFunction', {
      ...commonLambdaProps,
      functionName: `items-catalog-get-${stageName}`,
      entry: path.join(__dirname, '../lambda/get-item.ts'),
      handler: 'handler',
      description: 'Retrieves an item from the catalog by id',
    });

    const postItemFn = new NodejsFunction(this, 'PostItemFunction', {
      ...commonLambdaProps,
      functionName: `items-catalog-post-${stageName}`,
      entry: path.join(__dirname, '../lambda/post-item.ts'),
      handler: 'handler',
      description: 'Creates a new item in the catalog',
    });

    const deleteItemFn = new NodejsFunction(this, 'DeleteItemFunction', {
      ...commonLambdaProps,
      functionName: `items-catalog-delete-${stageName}`,
      entry: path.join(__dirname, '../lambda/delete-item.ts'),
      handler: 'handler',
      description: 'Deletes an item from the catalog by id',
    });

    table.grantReadData(getItemFn);
    table.grantWriteData(postItemFn);
    table.grantWriteData(deleteItemFn);

    const accessLogGroup = new logs.LogGroup(this, 'ApiAccessLogs', {
      logGroupName: `/aws/apigateway/items-catalog-${stageName}`,
      retention: logs.RetentionDays.ONE_MONTH,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    const api = new apigateway.RestApi(this, 'ItemsCatalogApi', {
      restApiName: `items-catalog-api-${stageName}`,
      description: 'REST API for the items catalog',
      deployOptions: {
        stageName,
        loggingLevel: apigateway.MethodLoggingLevel.INFO,
        dataTraceEnabled: false,
        metricsEnabled: true,
        tracingEnabled: true,
        throttlingBurstLimit: 200,
        throttlingRateLimit: 100,
        accessLogDestination: new apigateway.LogGroupLogDestination(accessLogGroup),
        accessLogFormat: apigateway.AccessLogFormat.jsonWithStandardFields({
          caller: true,
          httpMethod: true,
          ip: true,
          protocol: true,
          requestTime: true,
          resourcePath: true,
          responseLength: true,
          status: true,
          user: true,
        }),
      },
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: ['GET', 'POST', 'DELETE', 'OPTIONS'],
        allowHeaders: ['Content-Type', 'Authorization', 'X-Amz-Date', 'X-Api-Key', 'X-Amz-Security-Token'],
        maxAge: cdk.Duration.hours(1),
      },
      cloudWatchRole: true,
      endpointTypes: [apigateway.EndpointType.REGIONAL],
      minCompressionSize: cdk.Size.bytes(1024),
    });

    const requestValidator = new apigateway.RequestValidator(this, 'RequestValidator', {
      restApi: api,
      validateRequestBody: true,
      validateRequestParameters: true,
    });

    const