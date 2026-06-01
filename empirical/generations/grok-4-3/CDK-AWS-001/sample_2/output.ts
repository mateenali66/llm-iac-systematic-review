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
      tableName: 'items-catalog',
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
      pointInTimeRecovery: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
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
        const { DynamoDBClient, ScanCommand } = require('@aws-sdk/client-dynamodb');
        const { marshall, unmarshall } = require('@aws-sdk/util-dynamodb');
        const client = new DynamoDBClient({});
        exports.handler = async () => {
          const result = await client.send(new ScanCommand({ TableName: process.env.TABLE_NAME }));
          return { statusCode: 200, body: JSON.stringify(result.Items?.map(i => unmarshall(i)) || []) };
        };
      `),
      environment: { TABLE_NAME: table.tableName },
      role: lambdaRole,
      timeout: cdk.Duration.seconds(30),
      memorySize: 256,
    });

    const postItemFn = new lambda.Function(this, 'PostItemFunction', {
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const { DynamoDBClient, PutItemCommand } = require('@aws-sdk/client-dynamodb');
        const { marshall } = require('@aws-sdk/util-dynamodb');
        const client = new DynamoDBClient({});
        exports.handler = async (event) => {
          const item = JSON.parse(event.body);
          if (!item.id) return { statusCode: 400, body: 'id required' };
          await client.send(new PutItemCommand({ TableName: process.env.TABLE_NAME, Item: marshall(item) }));
          return { statusCode: 201, body: JSON.stringify(item) };
        };
      `),
      environment: { TABLE_NAME: table.tableName },
      role: lambdaRole,
      timeout: cdk.Duration.seconds(30),
      memorySize: 256,
    });

    const deleteItemFn = new lambda.Function(this, 'DeleteItemFunction', {
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const { DynamoDBClient, DeleteItemCommand } = require('@aws-sdk/client-dynamodb');
        const client = new DynamoDBClient({});
        exports.handler = async (event) => {
          const id = event.pathParameters?.id;
          if (!id) return { statusCode: 400, body: 'id required' };
          await client.send(new DeleteItemCommand({ TableName: process.env.TABLE_NAME, Key: { id: { S: id } } }));
          return { statusCode: 204, body: '' };
        };
      `),
      environment: { TABLE_NAME: table.tableName },
      role: lambdaRole,
      timeout: cdk.Duration.seconds(30),
      memorySize: 256,
    });

    table.grantReadData(getItemsFn);
    table.grantWriteData(postItemFn);
    table.grantWriteData(deleteItemFn);

    const api = new apigateway.RestApi(this, 'ItemsApi', {
      restApiName: 'items-catalog-api',
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

    const items = api.root.addResource('items');
    items.addMethod('GET', new apigateway.LambdaIntegration(getItemsFn));
    items.addMethod('POST', new apigateway.LambdaIntegration(postItemFn));

    const item = items.addResource('{id}');
    item.addMethod('DELETE', new apigateway.LambdaIntegration(deleteItemFn));
  }
}