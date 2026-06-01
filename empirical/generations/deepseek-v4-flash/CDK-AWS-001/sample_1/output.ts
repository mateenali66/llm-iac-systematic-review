import * as cdk from 'aws-cdk-lib';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export class ItemsCatalogStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // DynamoDB table for items catalog
    const itemsTable = new dynamodb.Table(this, 'ItemsTable', {
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
      pointInTimeRecovery: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // Lambda functions
    const getItemFunction = new lambda.Function(this, 'GetItemFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const dynamodb = new AWS.DynamoDB.DocumentClient();
        exports.handler = async (event) => {
          try {
            const itemId = event.pathParameters?.id;
            if (!itemId) {
              return { statusCode: 400, body: JSON.stringify({ error: 'Missing item ID' }) };
            }
            const params = { TableName: process.env.TABLE_NAME, Key: { id: itemId } };
            const result = await dynamodb.get(params).promise();
            if (!result.Item) {
              return { statusCode: 404, body: JSON.stringify({ error: 'Item not found' }) };
            }
            return { statusCode: 200, body: JSON.stringify(result.Item) };
          } catch (error) {
            return { statusCode: 500, body: JSON.stringify({ error: 'Internal server error' }) };
          }
        };
      `),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
      timeout: cdk.Duration.seconds(10),
      memorySize: 128,
    });

    const createItemFunction = new lambda.Function(this, 'CreateItemFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const dynamodb = new AWS.DynamoDB.DocumentClient();
        exports.handler = async (event) => {
          try {
            const body = JSON.parse(event.body || '{}');
            if (!body.id || !body.name) {
              return { statusCode: 400, body: JSON.stringify({ error: 'Missing required fields: id, name' }) };
            }
            const params = { TableName: process.env.TABLE_NAME, Item: body };
            await dynamodb.put(params).promise();
            return { statusCode: 201, body: JSON.stringify({ message: 'Item created', item: body }) };
          } catch (error) {
            return { statusCode: 500, body: JSON.stringify({ error: 'Internal server error' }) };
          }
        };
      `),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
      timeout: cdk.Duration.seconds(10),
      memorySize: 128,
    });

    const deleteItemFunction = new lambda.Function(this, 'DeleteItemFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const dynamodb = new AWS.DynamoDB.DocumentClient();
        exports.handler = async (event) => {
          try {
            const itemId = event.pathParameters?.id;
            if (!itemId) {
              return { statusCode: 400, body: JSON.stringify({ error: 'Missing item ID' }) };
            }
            const params = { TableName: process.env.TABLE_NAME, Key: { id: itemId } };
            await dynamodb.delete(params).promise();
            return { statusCode: 200, body: JSON.stringify({ message: 'Item deleted' }) };
          } catch (error) {
            return { statusCode: 500, body: JSON.stringify({ error: 'Internal server error' }) };
          }
        };
      `),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
      timeout: cdk.Duration.seconds(10),
      memorySize: 128,
    });

    // Grant Lambda functions access to DynamoDB table
    itemsTable.grantReadData(getItemFunction);
    itemsTable.grantWriteData(createItemFunction);
    itemsTable.grantWriteData(deleteItemFunction);

    // API Gateway REST API
    const api = new apigateway.RestApi(this, 'ItemsApi', {
      restApiName: 'Items Catalog API',
      description: 'API for managing items catalog',
      deployOptions: {
        stageName: 'prod',
        loggingLevel: apigateway.MethodLoggingLevel.INFO,
        dataTraceEnabled: true,
        metricsEnabled: true,
      },
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: apigateway.Cors.ALL_METHODS,
        allowHeaders: ['Content-Type', 'X-Amz-Date', 'Authorization', 'X-Api-Key'],
      },
    });

    // Items resource
    const items = api.root.addResource('items');
    const item = items.addResource('{id}');

    // GET /items/{id}
    item.addMethod('GET', new apigateway.LambdaIntegration(getItemFunction, {
      proxy: true,
    }));

    // POST /items
    items.addMethod('POST', new apigateway.LambdaIntegration(createItemFunction, {
      proxy: true,
    }));

    // DELETE /items/{id}
    item.addMethod('DELETE', new apigateway.LambdaIntegration(deleteItemFunction, {
      proxy: true,
    }));

    // Output the API endpoint URL
    new cdk.CfnOutput(this, 'ApiEndpoint', {
      value: api.url,
      description: 'API Gateway endpoint URL',
    });
  }
}