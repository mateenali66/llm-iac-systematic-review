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

    // Common Lambda role with DynamoDB access
    const lambdaRole = new iam.Role(this, 'LambdaExecutionRole', {
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
      ],
    });
    itemsTable.grantReadWriteData(lambdaRole);

    // Lambda functions
    const getItemsFunction = new lambda.Function(this, 'GetItemsFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
        const { DynamoDBDocumentClient, ScanCommand } = require('@aws-sdk/lib-dynamodb');
        const client = new DynamoDBClient({});
        const docClient = DynamoDBDocumentClient.from(client);
        exports.handler = async (event) => {
          try {
            const command = new ScanCommand({ TableName: process.env.TABLE_NAME });
            const response = await docClient.send(command);
            return {
              statusCode: 200,
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(response.Items || []),
            };
          } catch (error) {
            return {
              statusCode: 500,
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ error: error.message }),
            };
          }
        };
      `),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
      role: lambdaRole,
    });

    const postItemFunction = new lambda.Function(this, 'PostItemFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
        const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');
        const client = new DynamoDBClient({});
        const docClient = DynamoDBDocumentClient.from(client);
        exports.handler = async (event) => {
          try {
            const body = JSON.parse(event.body);
            const id = body.id || crypto.randomUUID();
            const item = { id, ...body };
            const command = new PutCommand({ TableName: process.env.TABLE_NAME, Item: item });
            await docClient.send(command);
            return {
              statusCode: 201,
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(item),
            };
          } catch (error) {
            return {
              statusCode: 500,
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ error: error.message }),
            };
          }
        };
      `),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
      role: lambdaRole,
    });

    const deleteItemFunction = new lambda.Function(this, 'DeleteItemFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
        const { DynamoDBDocumentClient, DeleteCommand } = require('@aws-sdk/lib-dynamodb');
        const client = new DynamoDBClient({});
        const docClient = DynamoDBDocumentClient.from(client);
        exports.handler = async (event) => {
          try {
            const id = event.pathParameters?.id;
            if (!id) {
              return {
                statusCode: 400,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ error: 'Missing id path parameter' }),
              };
            }
            const command = new DeleteCommand({ TableName: process.env.TABLE_NAME, Key: { id } });
            await docClient.send(command);
            return {
              statusCode: 204,
              headers: { 'Content-Type': 'application/json' },
              body: '',
            };
          } catch (error) {
            return {
              statusCode: 500,
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ error: error.message }),
            };
          }
        };
      `),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
      role: lambdaRole,
    });

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

    // GET /items
    items.addMethod('GET', new apigateway.LambdaIntegration(getItemsFunction, {
      proxy: true,
    }));

    // POST /items
    items.addMethod('POST', new apigateway.LambdaIntegration(postItemFunction, {
      proxy: true,
    }));

    // DELETE /items/{id}
    const singleItem = items.addResource('{id}');
    singleItem.addMethod('DELETE', new apigateway.LambdaIntegration(deleteItemFunction, {
      proxy: true,
    }));
  }
}