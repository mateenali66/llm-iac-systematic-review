import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as iam from 'aws-cdk-lib/aws-iam';

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

    const commonLambdaProps = {
      runtime: lambda.Runtime.NODEJS_20_X,
      timeout: cdk.Duration.seconds(30),
      memorySize: 256,
      environment: {
        TABLE_NAME: table.tableName,
      },
      tracing: lambda.Tracing.ACTIVE,
    };

    const getLambda = new lambda.Function(this, 'GetItemsFunction', {
      ...commonLambdaProps,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const dynamo = new AWS.DynamoDB.DocumentClient();
        exports.handler = async (event) => {
          const params = { TableName: process.env.TABLE_NAME };
          const result = await dynamo.scan(params).promise();
          return { statusCode: 200, body: JSON.stringify(result.Items) };
        };
      `),
    });

    const postLambda = new lambda.Function(this, 'PostItemFunction', {
      ...commonLambdaProps,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const dynamo = new AWS.DynamoDB.DocumentClient();
        exports.handler = async (event) => {
          const body = JSON.parse(event.body);
          const params = { TableName: process.env.TABLE_NAME, Item: body };
          await dynamo.put(params).promise();
          return { statusCode: 201, body: JSON.stringify(body) };
        };
      `),
    });

    const deleteLambda = new lambda.Function(this, 'DeleteItemFunction', {
      ...commonLambdaProps,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const dynamo = new AWS.DynamoDB.DocumentClient();
        exports.handler = async (event) => {
          const id = event.pathParameters.id;
          const params = { TableName: process.env.TABLE_NAME, Key: { id } };
          await dynamo.delete(params).promise();
          return { statusCode: 204, body: '' };
        };
      `),
    });

    table.grantReadData(getLambda);
    table.grantWriteData(postLambda);
    table.grantWriteData(deleteLambda);

    const api = new apigateway.RestApi(this, 'ItemsApi', {
      restApiName: 'ItemsCatalogApi',
      deployOptions: {
        stageName: 'prod',
        loggingLevel: apigateway.MethodLoggingLevel.INFO,
        dataTraceEnabled: true,
        tracingEnabled: true,
      },
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: apigateway.Cors.ALL_METHODS,
      },
    });

    const items = api.root.addResource('items');
    items.addMethod('GET', new apigateway.LambdaIntegration(getLambda));
    items.addMethod('POST', new apigateway.LambdaIntegration(postLambda));

    const item = items.addResource('{id}');
    item.addMethod('DELETE', new apigateway.LambdaIntegration(deleteLambda));

    new cdk.CfnOutput(this, 'ApiUrl', { value: api.url });
  }
}