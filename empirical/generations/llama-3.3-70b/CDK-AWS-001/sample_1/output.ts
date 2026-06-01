import * as cdk from 'aws-cdk-lib';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';

export class ItemsCatalogStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const itemsTable = new dynamodb.Table(this, 'ItemsTable', {
      tableName: 'items-catalog',
      attributeDefinitions: [
        {
          AttributeName: 'id',
          AttributeType: 'S',
        },
      ],
      keySchema: [
        {
          AttributeName: 'id',
          KeyType: 'HASH',
        },
      ],
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
    });

    const getItemsFunction = new lambda.Function(this, 'GetItemsFunction', {
      functionName: 'get-items',
      runtime: lambda.Runtime.NODEJS_16_X,
      handler: 'index.handler',
      code: lambda.Code.fromAsset('lambda'),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
    });

    itemsTable.grantReadData(getItemsFunction);

    const postItemFunction = new lambda.Function(this, 'PostItemFunction', {
      functionName: 'post-item',
      runtime: lambda.Runtime.NODEJS_16_X,
      handler: 'index.handler',
      code: lambda.Code.fromAsset('lambda'),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
    });

    itemsTable.grantWriteData(postItemFunction);

    const deleteItemFunction = new lambda.Function(this, 'DeleteItemFunction', {
      functionName: 'delete-item',
      runtime: lambda.Runtime.NODEJS_16_X,
      handler: 'index.handler',
      code: lambda.Code.fromAsset('lambda'),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
    });

    itemsTable.grantDeleteData(deleteItemFunction);

    const api = new apigateway.RestApi(this, 'ItemsApi', {
      restApiName: 'items-api',
      description: 'API for items catalog',
    });

    const itemsResource = api.root.addResource('items');

    itemsResource.addMethod('GET', {
      integration: new apigateway.LambdaIntegration(getItemsFunction, {
        requestTemplates: {
          'application/json': '{"statusCode": "200"}',
        },
      }),
      authorizationType: apigateway.AuthorizationType.NONE,
    });

    itemsResource.addMethod('POST', {
      integration: new apigateway.LambdaIntegration(postItemFunction, {
        requestTemplates: {
          'application/json': '{"statusCode": "200"}',
        },
      }),
      authorizationType: apigateway.AuthorizationType.NONE,
    });

    itemsResource.addMethod('DELETE', {
      integration: new apigateway.LambdaIntegration(deleteItemFunction, {
        requestTemplates: {
          'application/json': '{"statusCode": "200"}',
        },
      }),
      authorizationType: apigateway.AuthorizationType.NONE,
    });
  }
}