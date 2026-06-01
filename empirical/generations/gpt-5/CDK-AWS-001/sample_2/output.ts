import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as nodejs from 'aws-cdk-lib/aws-lambda-nodejs';
import * as path from 'path';

export interface CatalogApiStackProps extends cdk.StackProps {
  stageName?: string;
}

export class CatalogApiStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: CatalogApiStackProps = {}) {
    super(scope, id, props);

    const table = new dynamodb.Table(this, 'ItemsTable', {
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      pointInTimeRecovery: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
    });

    const logRetention = logs.RetentionDays.ONE_YEAR;

    const commonLambdaEnv = {
      TABLE_NAME: table.tableName,
      AWS_NODEJS_CONNECTION_REUSE_ENABLED: '1',
    };

    const commonLambdaProps: Omit<nodejs.NodejsFunctionProps, 'entry'> = {
      handler: 'handler',
      runtime: lambda.Runtime.NODEJS_20_X,
      architecture: lambda.Architecture.ARM_64,
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      environment: commonLambdaEnv,
      logRetention,
      tracing: lambda.Tracing.ACTIVE,
      bundling: {
        minify: true,
        sourceMap: true,
        target: 'node20',
        externalModules: ['aws-sdk'],
      },
      reservedConcurrentExecutions: 10,
    };

    const getItemsFn = new nodejs.NodejsFunction(this, 'GetItemsFunction', {
      entry: path.join(__dirname, '../lambda/get.ts'),
      ...commonLambdaProps,
    });

    const postItemFn = new nodejs.NodejsFunction(this, 'PostItemFunction', {
      entry: path.join(__dirname, '../lambda/post.ts'),
      ...commonLambdaProps,
    });

    const deleteItemFn = new nodejs.NodejsFunction(this, 'DeleteItemFunction', {
      entry: path.join(__dirname, '../lambda/delete.ts'),
      ...commonLambdaProps,
    });

    table.grantReadData(getItemsFn);
    table.grantWriteData(postItemFn);
    table.grantWriteData(deleteItemFn);

    const apiAccessLogs = new logs.LogGroup(this, 'ApiAccessLogs', {
      retention: logs.RetentionDays.ONE_YEAR,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    const api = new apigateway.RestApi(this, 'CatalogApi', {
      restApiName: 'catalog-api',
      description: 'Items catalog API with GET, POST, and DELETE operations',
      cloudWatchRole: true,
      deployOptions: {
        stageName: props.stageName ?? 'prod',
        tracingEnabled: true,
        loggingLevel: apigateway.MethodLoggingLevel.INFO,
        dataTraceEnabled: false,
        metricsEnabled: true,
        accessLogDestination: new apigateway.LogGroupLogDestination(apiAccessLogs),
        accessLogFormat: apigateway.AccessLogFormat.jsonWithStandardFields({
          caller: false,
          httpMethod: true,
          ip: true,
          protocol: true,
          requestTime: true,
          resourcePath: true,
          responseLength: true,
          status: true,
          user: false,
        }),
      },
      defaultCorsPreflightOptions: {
        allowOrigins: [], // Intentionally empty; configure explicitly as needed
        allowMethods: ['GET', 'POST', 'DELETE'],
      },
    });

    const items = api.root.addResource('items');

    items.addMethod('GET', new apigateway.LambdaIntegration(getItemsFn, { proxy: true }), {
      authorizationType: apigateway.AuthorizationType.NONE,
    });

    items.addMethod('POST', new apigateway.LambdaIntegration(postItemFn, { proxy: true }), {
      authorizationType: apigateway.AuthorizationType.NONE,
    });

    const itemById = items.addResource('{id}');
    itemById.addMethod('DELETE', new apigateway.LambdaIntegration(deleteItemFn, { proxy: true }), {
      authorizationType: apigateway.AuthorizationType.NONE,
      requestParameters: {
        'method.request.path.id': true,
      },
    });

    new cdk.CfnOutput(this, 'ApiUrl', {
      value: api.url,
    });

    new cdk.CfnOutput(this, 'DynamoDbTableName', {
      value: table.tableName,
    });
  }
}