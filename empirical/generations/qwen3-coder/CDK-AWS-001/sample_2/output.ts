import * as cdk from 'aws-cdk-lib';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as path from 'path';
import { Construct } from 'constructs';

export class ItemsCatalogStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // DynamoDB Table
    const itemsTable = new dynamodb.Table(this, 'ItemsTable', {
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      pointInTimeRecovery: true,
    });

    // Lambda Functions
    const getFunction = new lambda.Function(this, 'GetItemFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromAsset(path.join(__dirname, 'lambda/get')),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
    });

    const postFunction = new lambda.Function(this, 'PostItemFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromAsset(path.join(__dirname, 'lambda/post')),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
    });

    const deleteFunction = new lambda.Function(this, 'DeleteItemFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromAsset(path.join(__dirname, 'lambda/delete')),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
    });

    // Grant Lambda functions access to DynamoDB
    itemsTable.grantReadData(getFunction);
    itemsTable.grantWriteData(postFunction);
    itemsTable.grantReadWriteData(deleteFunction);

    // API Gateway
    const api = new apigateway.RestApi(this, 'ItemsCatalogApi', {
      restApiName: 'Items Catalog Service',
      description: 'API for managing items catalog',
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: apigateway.Cors.ALL_METHODS,
      },
      deployOptions: {
        stageName: 'prod',
        loggingLevel: apigateway.MethodLoggingLevel.INFO,
        dataTraceEnabled: true,
        metricsEnabled: true,
      },
      cloudWatchRole: true,
    });

    // API Gateway Resources and Methods
    const items = api.root.addResource('items');
    const item = items.addResource('{id}');

    // GET /items/{id}
    const getIntegration = new apigateway.LambdaIntegration(getFunction);
    item.addMethod('GET', getIntegration, {
      apiKeyRequired: false,
    });

    // POST /items
    const postIntegration = new apigateway.LambdaIntegration(postFunction);
    items.addMethod('POST', postIntegration, {
      apiKeyRequired: false,
    });

    // DELETE /items/{id}
    const deleteIntegration = new apigateway.LambdaIntegration(deleteFunction);
    item.addMethod('DELETE', deleteIntegration, {
      apiKeyRequired: false,
    });

    // Output
    new cdk.CfnOutput(this, 'APIEndpoint', {
      value: api.url,
      description: 'API Gateway endpoint URL',
    });

    new cdk.CfnOutput(this, 'TableName', {
      value: itemsTable.tableName,
      description: 'DynamoDB table name',
    });
  }
}