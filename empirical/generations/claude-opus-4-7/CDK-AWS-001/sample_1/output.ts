import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as lambdaNodejs from 'aws-cdk-lib/aws-lambda-nodejs';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as logs from 'aws-cdk-lib/aws-logs';
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

    // DynamoDB Table
    this.table = new dynamodb.Table(this, 'ItemsTable', {
      tableName: `${id}-items`,
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
      pointInTimeRecoverySpecification: { pointInTimeRecoveryEnabled: true },
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      deletionProtection: true,
      contributorInsightsEnabled: true,
    });

    // Common Lambda properties
    const commonLambdaProps: Partial<lambdaNodejs.NodejsFunctionProps> = {
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
      bundling: {
        minify: true,
        sourceMap: true,
        target: 'node20',
      },
    };

    const getItemFn = new lambdaNodejs.NodejsFunction(this, 'GetItemFunction', {
      ...commonLambdaProps,
      entry: path.join(__dirname, '..', 'lambda', 'get-item.ts'),
      handler: 'handler',
      description: 'Retrieves item(s) from the catalog',
    });

    const createItemFn = new lambdaNodejs.NodejsFunction(this, 'CreateItemFunction', {
      ...commonLambdaProps,
      entry: path.join(__dirname, '..', 'lambda', 'create-item.ts'),
      handler: 'handler',
      description: 'Creates a new item in the catalog',
    });

    const deleteItemFn = new lambdaNodejs.NodejsFunction(this, 'DeleteItemFunction', {
      ...commonLambdaProps,
      entry: path.join(__dirname, '..', 'lambda', 'delete-item.ts'),
      handler: 'handler',
      description: 'Deletes an item from the catalog',
    });

    // Grant least-privilege permissions
    this.table.grantReadData(getItemFn);
    this.table.grantWriteData(createItemFn);
    this.table.grantWriteData(deleteItemFn);

    // API Gateway access logs
    const apiAccessLogGroup = new logs.LogGroup(this, 'ApiAccessLogs', {
      retention: logs.RetentionDays.ONE_MONTH,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // REST API
    this.api = new apigateway.RestApi(this, 'ItemsApi', {
      restApiName: `${id}-api`,
      description: 'Items catalog REST API',
      deployOptions: {
        stageName,
        tracingEnabled: true,
        loggingLevel: apigateway.MethodLoggingLevel.INFO,
        dataTraceEnabled: false,
        metricsEnabled: true,
        throttlingBurstLimit: 200,
        throttlingRateLimit: 100,
        accessLogDestination: new apigateway.LogGroupLogDestination(apiAccessLogGroup),
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
      cloudWatchRole: true,
      endpointTypes: [apigateway.EndpointType.REGIONAL],
    });

    // Request validator
    const requestValidator = new apigateway.RequestValidator(this, 'RequestValidator', {
      restApi: this.api,
      validateRequestBody: true,
      validateRequestParameters: true,
    });

    //