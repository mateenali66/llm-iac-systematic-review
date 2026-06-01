import * as cdk from 'aws-cdk-lib';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export class ItemsCatalogStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // DynamoDB Table
    const itemsTable = new dynamodb.Table(this, 'ItemsTable', {
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
      pointInTimeRecovery: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // Lambda Execution Role
    const lambdaRole = new iam.Role(this, 'LambdaExecutionRole', {
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
      ],
    });

    // Grant DynamoDB permissions to Lambda role
    itemsTable.grantReadWriteData(lambdaRole);

    // GET Lambda Function
    const getItemsFunction = new lambda.Function(this, 'GetItemsFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const dynamoDb = new AWS.DynamoDB.DocumentClient();
        
        exports.handler = async (event) => {
          const params = {
            TableName: process.env.TABLE_NAME,
          };
          
          try {
            const result = await dynamoDb.scan(params).promise();
            return {
              statusCode: 200,
              headers: {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
              },
              body: JSON.stringify(result.Items)
            };
          } catch (error) {
            return {
              statusCode: 500,
              headers: {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
              },
              body: JSON.stringify({ error: 'Could not retrieve items' })
            };
          }
        };
      `),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
      role: lambdaRole,
      timeout: cdk.Duration.seconds(30),
    });

    // POST Lambda Function
    const createItemFunction = new lambda.Function(this, 'CreateItemFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const dynamoDb = new AWS.DynamoDB.DocumentClient();
        const uuid = require('uuid');
        
        exports.handler = async (event) => {
          const data = JSON.parse(event.body);
          const params = {
            TableName: process.env.TABLE_NAME,
            Item: {
              id: uuid.v4(),
              name: data.name,
              description: data.description,
              price: data.price,
              createdAt: new Date().toISOString()
            }
          };
          
          try {
            await dynamoDb.put(params).promise();
            return {
              statusCode: 201,
              headers: {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
              },
              body: JSON.stringify(params.Item)
            };
          } catch (error) {
            return {
              statusCode: 500,
              headers: {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
              },
              body: JSON.stringify({ error: 'Could not create item' })
            };
          }
        };
      `),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
      role: lambdaRole,
      timeout: cdk.Duration.seconds(30),
    });

    // Add uuid dependency layer for POST function
    createItemFunction.addLayers(
      new lambda.LayerVersion(this, 'UuidLayer', {
        code: lambda.Code.fromInline(`
          nodejs/node18.x/node_modules/uuid/
        `),
        compatibleRuntimes: [lambda.Runtime.NODEJS_18_X],
      })
    );

    // DELETE Lambda Function
    const deleteItemFunction = new lambda.Function(this, 'DeleteItemFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const dynamoDb = new AWS.DynamoDB.DocumentClient();
        
        exports.handler = async (event) => {
          const params = {
            TableName: process.env.TABLE_NAME,
            Key: {
              id: event.pathParameters.id
            }
          };
          
          try {
            await dynamoDb.delete(params).promise();
            return {
              statusCode: 200,
              headers: {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
              },
              body: JSON.stringify({ message: 'Item deleted successfully' })
            };
          } catch (error) {
            return {
              statusCode: 500,
              headers: {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
              },
              body: JSON.stringify({ error: 'Could not delete item' })
            };
          }
        };
      `),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
      role: lambdaRole,
      timeout: cdk.Duration.seconds(30),
    });

    // API Gateway
    const api = new apigateway.RestApi(this, 'ItemsCatalogApi', {
      restApiName: 'Items Catalog Service',
      description: 'API for managing items catalog',
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: apigateway.Cors.ALL_METHODS,
        allowHeaders: apigateway.Cors.DEFAULT_HEADERS,
      },
      deployOptions: {
        stageName: 'prod',
        loggingLevel: apigateway.MethodLoggingLevel.ERROR,
        dataTraceEnabled: false,
        metricsEnabled: true,
        throttlingRateLimit: 100,
        throttlingBurstLimit: 50,
      },
      cloudWatchRole: true,
    });

    // API Gateway Resources and Methods
    const itemsResource = api.root.addResource('items');

    // GET /items
    itemsResource.addMethod('GET', new apigateway.LambdaIntegration(getItemsFunction), {
      authorizationType: apigateway.AuthorizationType.NONE,
    });

    // POST /items
    itemsResource.addMethod('POST', new apigateway.LambdaIntegration(createItemFunction), {
      authorizationType: apigateway.AuthorizationType.NONE,
    });

    // DELETE /items/{id}
    const itemResource = itemsResource.addResource('{id}');
    itemResource.addMethod('DELETE', new apigateway.LambdaIntegration(deleteItemFunction), {
      authorizationType: apigateway.AuthorizationType.NONE,
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