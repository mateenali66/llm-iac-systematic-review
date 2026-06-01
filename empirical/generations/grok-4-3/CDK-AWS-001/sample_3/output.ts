import * as cdk from 'aws-cdk-lib';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import { Construct } from 'constructs';

export class ItemsCatalogStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const table = new dynamodb.Table(this, 'ItemsTable', {
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      pointInTimeRecovery: true,
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
    });

    const lambdaRole = new iam.Role(this, 'LambdaExecutionRole', {
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
      ],
    });

    const getItemsFn = new lambda.Function(this, 'GetItemsFunction', {
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const dynamo = new AWS.DynamoDB.DocumentClient();
        exports.handler = async () => {
          const data = await dynamo.scan({ TableName: process.env.TABLE_NAME }).promise();
          return { statusCode: 200, body: JSON.stringify(data.Items) };
        };
      `),
      environment: { TABLE_NAME: table.tableName },
      role: lambdaRole,
      timeout: cdk.Duration.seconds(30),
      memorySize: 256,
    });
    table.grantReadData(getItemsFn);

    const postItemsFn = new lambda.Function(this, 'PostItemsFunction', {
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const dynamo = new AWS.DynamoDB.DocumentClient();
        exports.handler = async (event) => {
          const item = JSON.parse(event.body);
          item.id = item.id || require('crypto').randomUUID();
          await dynamo.put({ TableName: process.env.TABLE_NAME, Item: item }).promise();
          return { statusCode: 201, body: JSON.stringify(item) };
        };
      `),
      environment: { TABLE_NAME: table.tableName },
      role: lambdaRole,
      timeout: cdk.Duration.seconds(30),
      memorySize: 256,
    });
    table.grantWriteData(postItemsFn);

    const deleteItemsFn = new lambda.Function(this, 'DeleteItemsFunction', {
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const dynamo = new AWS.DynamoDB.DocumentClient();
        exports.handler = async (event) => {
          const id = event.pathParameters.id;
          await dynamo.delete({ TableName: process.env.TABLE_NAME, Key: { id } }).promise();
          return { statusCode: 204, body: '' };
        };
      `),
      environment: { TABLE_NAME: table.tableName },
      role: lambdaRole,
      timeout: cdk.Duration.seconds(30),
      memorySize: 256,
    });
    table.grantWriteData(deleteItemsFn);

    const api = new apigateway.RestApi(this, 'ItemsApi', {
      restApiName: 'ItemsCatalogApi',
      deployOptions: {
        stageName: 'prod',
        loggingLevel: apigateway.MethodLoggingLevel.INFO,
        dataTraceEnabled: true,
        metricsEnabled: true,
      },
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: apigateway.Cors.ALL_METHODS,
      },
    });

    const itemsResource = api.root.addResource('items');
    itemsResource.addMethod('GET', new apigateway.LambdaIntegration(getItemsFn));
    itemsResource.addMethod('POST', new apigateway.LambdaIntegration(postItemsFn));

    const itemResource = itemsResource.addResource('{id}');
    itemResource.addMethod('DELETE', new apigateway.LambdaIntegration(deleteItemsFn));
  }
}