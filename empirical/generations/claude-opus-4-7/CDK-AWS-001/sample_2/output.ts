import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as logs from 'aws-cdk-lib/aws-logs';
import { NodejsFunction } from 'aws-cdk-lib/aws-lambda-nodejs';
import * as path from 'path';

export interface ItemsCatalogStackProps extends cdk.StackProps {
  readonly stageName?: string;
}

export class ItemsCatalogStack extends cdk.Stack {
  public readonly api: apigateway.RestApi;
  public readonly table: dynamodb.Table;

  constructor(scope: Construct, id: string, props: ItemsCatalogStackProps = {}) {
    super(scope, id, props);

    const stageName = props.stageName ?? 'prod';

    this.table = new dynamodb.Table(this, 'ItemsTable', {
      tableName: `${id}-items`,
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
      pointInTimeRecovery: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      deletionProtection: true,
      contributorInsightsEnabled: true,
    });

    const commonLambdaProps: Omit<lambda.FunctionProps, 'code' | 'handler'> = {
      runtime: lambda.Runtime.NODEJS_20_X,
      architecture: lambda.Architecture.ARM_64,
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      tracing: lambda.Tracing.ACTIVE,
      logRetention: logs.RetentionDays.ONE_MONTH,
      environment: {
        TABLE_NAME: this.table.tableName,
        NODE_OPTIONS: '--enable-source-maps',
        POWERTOOLS_SERVICE_NAME: 'items-catalog',
      },
    };

    const bundling = {
      minify: true,
      sourceMap: true,
      target: 'node20',
      externalModules: ['@aws-sdk/*'],
    };

    const getItemFn = new NodejsFunction(this, 'GetItemFunction', {
      ...commonLambdaProps,
      entry: path.join(__dirname, '../lambda/get-item.ts'),
      handler: 'handler',
      description: 'GET /items/{id} - retrieve an item',
      bundling,
    });

    const postItemFn = new NodejsFunction(this, 'PostItemFunction', {
      ...commonLambdaProps,
      entry: path.join(__dirname, '../lambda/post-item.ts'),
      handler: 'handler',
      description: 'POST /items - create an item',
      bundling,
    });

    const deleteItemFn = new NodejsFunction(this, 'DeleteItemFunction', {
      ...commonLambdaProps,
      entry: path.join(__dirname, '../lambda/delete-item.ts'),
      handler: 'handler',
      description: 'DELETE /items/{id} - delete an item',
      bundling,
    });

    this.table.grantReadData(getItemFn);
    this.table.grantWriteData(postItemFn);
    this.table.grantWriteData(deleteItemFn);

    const accessLogGroup = new logs.LogGroup(this, 'ApiAccessLogs', {
      retention: logs.RetentionDays.ONE_MONTH,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    this.api = new apigateway.RestApi(this, 'ItemsCatalogApi', {
      restApiName: `${id}-api`,
      description: 'Items catalog REST API',
      cloudWatchRole: true,
      deployOptions: {
        stageName,
        tracingEnabled: true,
        metricsEnabled: true,
        loggingLevel: apigateway.MethodLoggingLevel.INFO,
        dataTraceEnabled: false,
        throttlingBurstLimit: 200,
        throttlingRateLimit: 100,
        accessLogDestination: new apigateway.LogGroupLogDestination(accessLogGroup),
        accessLogFormat: apigateway.AccessLogFormat.jsonWithStandardFields({
          caller: false,
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
      endpointTypes: [apigateway.EndpointType.REGIONAL],
    });

    const itemModel = this.api.addModel('ItemModel', {
      contentType: 'application/json',
      modelName: 'ItemModel',
      schema: {
        schema: apigateway.JsonSchemaVersion.DRAFT4,
        title: 'Item',
        type: apigateway.JsonSchemaType.OBJECT,
        required: ['name'],
        properties: {
          id: { type: apigateway.JsonSchemaType.STRING },
          name