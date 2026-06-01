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

    const getItemsLambda = new lambda.Function(this, 'GetItemsLambda', {
      functionName: 'get-items-lambda',
      runtime: lambda.Runtime.NODEJS_16_X,
      handler: 'index.handler',
      code: lambda.Code.fromAsset('lambda'),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
    });

    itemsTable.grantReadData(getItemsLambda);

    const postItemLambda = new lambda.Function(this, 'PostItemLambda', {
      functionName: 'post-item-lambda',
      runtime: lambda.Runtime.NODEJS_16_X,
      handler: 'index.handler',
      code: lambda.Code.fromAsset('lambda'),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
    });

    itemsTable.grantWriteData(postItemLambda);

    const deleteItemLambda = new lambda.Function(this, 'DeleteItemLambda', {
      functionName: 'delete-item-lambda',
      runtime: lambda.Runtime.NODEJS_16_X,
      handler: 'index.handler',
      code: lambda.Code.fromAsset('lambda'),
      environment: {
        TABLE_NAME: itemsTable.tableName,
      },
    });

    itemsTable.grantDeleteData(deleteItemLambda);

    const api = new apigateway.RestApi(this, 'ItemsApi', {
      restApiName: 'items-api',
      description: 'API for items catalog',
    });

    const itemsResource = api.root.addResource('items');

    itemsResource.addMethod('GET', {
      integration: new apigateway.LambdaIntegration(getItemsLambda, {
        requestTemplates: {
          'application/json': '{"statusCode": "200"}',
        },
      }),
      authorizationType: apigateway.AuthorizationType.NONE,
    });

    itemsResource.addMethod('POST', {
      integration: new apigateway.LambdaIntegration(postItemLambda, {
        requestTemplates: {
          'application/json': '{"statusCode": "200"}',
        },
      }),
      authorizationType: apigateway.AuthorizationType.NONE,
    });

    itemsResource.addMethod('DELETE', {
      integration: new apigateway.LambdaIntegration(deleteItemLambda, {
        requestTemplates: {
          'application/json': '{"statusCode": "200"}',
        },
      }),
      authorizationType: apigateway.AuthorizationType.NONE,
    });
  }
}