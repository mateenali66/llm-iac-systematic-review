import { Stack, StackProps, RemovalPolicy, Duration, CfnOutput } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigw from 'aws-cdk-lib/aws-apigateway';
import * as logs from 'aws-cdk-lib/aws-logs';

export class ItemsCatalogStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const table = new dynamodb.Table(this, 'ItemsTable', {
      tableName: `${Stack.of(this).stackName}-items`,
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      pointInTimeRecovery: true,
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
      removalPolicy: RemovalPolicy.RETAIN
    });

    const logRetention = logs.RetentionDays.THREE_MONTHS;

    const getFn = new lambda.Function(this, 'GetItemFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      architecture: lambda.Architecture.ARM_64,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const ddb = new AWS.DynamoDB.DocumentClient();
        const TABLE_NAME = process.env.TABLE_NAME;
        const PK = process.env.PRIMARY_KEY || 'id';

        const send = (statusCode, body) => {
          return {
            statusCode,
            headers: {
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Credentials': 'false',
              'Content-Type': 'application/json'
            },
            body: JSON.stringify(body)
          };
        };

        exports.handler = async (event) => {
          try {
            if (event.httpMethod !== 'GET') {
              return send(405, { message: 'Method Not Allowed' });
            }
            const id = event.pathParameters && event.pathParameters.id;
            if (id) {
              const resp = await ddb.get({ TableName: TABLE_NAME, Key: { [PK]: id } }).promise();
              if (!resp.Item) return send(404, { message: 'Not Found' });
              return send(200, resp.Item);
            } else {
              const limitParam = event.queryStringParameters && event.queryStringParameters.limit;
              const limit = Math.min(Math.max(parseInt(limitParam || '50', 10) || 50, 1), 100);
              const nextToken = event.queryStringParameters && event.queryStringParameters.nextToken;
              let ExclusiveStartKey = undefined;
              if (nextToken) {
                try { ExclusiveStartKey = JSON.parse(Buffer.from(nextToken, 'base64').toString('utf-8')); } catch (e) {}
              }
              const params = { TableName: TABLE_NAME, Limit: limit, ExclusiveStartKey };
              const resp = await ddb.scan(params).promise();
              const token = resp.LastEvaluatedKey ? Buffer.from(JSON.stringify(resp.LastEvaluatedKey)).toString('base64') : null;
              return send(200, { items: resp.Items || [], nextToken: token });
            }
          } catch (err) {
            console.error(err);
            return send(500, { message: 'Internal Server Error' });
          }
        };
      `),
      timeout: Duration.seconds(10),
      memorySize: 256,
      environment: {
        TABLE_NAME: table.tableName,
        PRIMARY_KEY: 'id'
      },
      description: 'GET items from DynamoDB',
      tracing: lambda.Tracing.ACTIVE,
      logRetention
    });
    table.grantReadData(getFn);

    const postFn = new lambda.Function(this, 'PostItemFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      architecture: lambda.Architecture.ARM_64,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const crypto = require('crypto');
        const ddb = new AWS.DynamoDB.DocumentClient();
        const TABLE_NAME = process.env.TABLE_NAME;
        const PK = process.env.PRIMARY_KEY || 'id';

        const send = (status, body) => ({
          statusCode: status,
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Credentials': 'false',
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(body)
        });

        exports.handler = async (event) => {
          try {
            if (event.httpMethod !== 'POST') return send(405, { message: 'Method Not Allowed' });
            if (!event.body) return send(400, { message: 'Missing body' });
            let data;
            try { data = JSON.parse(event.body); } catch { return send(400, { message: 'Invalid JSON' }); }

            let id = data[PK];
            if (!id || typeof id !== 'string' || !id.trim()) {
              if (crypto.randomUUID) id = crypto.randomUUID();
              else id = crypto.randomBytes(16).toString('hex');
            } else {
              id = id.trim();
            }

            const now = new Date().toISOString();
            const item = { ...data, [PK]: id, createdAt: now, updatedAt: now };

            await ddb.put({
              TableName: TABLE_NAME,
              Item: item,
              ConditionExpression: 'attribute_not_exists(#pk)',
              ExpressionAttributeNames: { '#pk': PK }
            }).promise();

            return send(201, item);
          } catch (err) {
            if (err && err.code === 'ConditionalCheckFailedException') {
              return send(409, { message: 'Item already exists' });
            }
            console.error(err);
            return send(500, { message: 'Internal Server Error' });
          }
        };
      `),
      timeout: Duration.seconds(10),
      memorySize: 256,
      environment: {
        TABLE_NAME: table.tableName,
        PRIMARY_KEY: 'id'
      },
      description: 'POST new item to DynamoDB',
      tracing: lambda.Tracing.ACTIVE,
      logRetention
    });
    table.grantWriteData(postFn);

    const deleteFn = new lambda.Function(this, 'DeleteItemFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      architecture: lambda.Architecture.ARM_64,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const ddb = new AWS.DynamoDB.DocumentClient();
        const TABLE_NAME = process.env.TABLE_NAME;
        const PK = process.env.PRIMARY_KEY || 'id';

        const send = (status, body) => ({
          statusCode: status,
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Credentials': 'false',
            'Content-Type': 'application/json'
          },
          body: body !== undefined ? JSON.stringify(body) : ''
        });

        exports.handler = async (event) => {
          try {
            if (event.httpMethod !== 'DELETE') return send(405, { message: 'Method Not Allowed' });
            const id = event.pathParameters && event.pathParameters.id;
            if (!id) return send(400, { message: 'Missing id' });

            await ddb.delete({
              TableName: TABLE_NAME,
              Key: { [PK]: id },
              ConditionExpression: 'attribute_exists(#pk)',
              ExpressionAttributeNames: { '#pk': PK }
            }).promise();

            return send(204);
          } catch (err) {
            if (err && err.code === 'ConditionalCheckFailedException') {
              return send(404, { message: 'Not Found' });
            }
            console.error(err);
            return send(500, { message: 'Internal Server Error' });
          }
        };
      `),
      timeout: Duration.seconds(10),
      memorySize: 256,
      environment: {
        TABLE_NAME: table.tableName,
        PRIMARY_KEY: 'id'
      },
      description: 'DELETE item from DynamoDB',
      tracing: lambda.Tracing.ACTIVE,
      logRetention
    });
    table.grantWriteData(deleteFn);

    const accessLogs = new logs.LogGroup(this, 'ApiAccessLogs', {
      retention: logs.RetentionDays.SIX_MONTHS,
      removalPolicy: RemovalPolicy.DESTROY
    });

    const api = new apigw.RestApi(this, 'ItemsApi', {
      restApiName: 'Items Catalog API',
      description: 'REST API for items catalog backed by Lambda and DynamoDB',
      cloudWatchRole: true,
      deployOptions: {
        stageName: 'prod',
        tracingEnabled: true,
        loggingLevel: apigw.MethodLoggingLevel.INFO,
        dataTraceEnabled: false,
        metricsEnabled: true,
        accessLogDestination: new apigw.LogGroupLogDestination(accessLogs),
        accessLogFormat: apigw.AccessLogFormat.jsonWithStandardFields({
          caller: true,
          httpMethod: true,
          ip: true,
          protocol: true,
          requestTime: true,
          resourcePath: true,
          responseLength: true,
          status: true,
          user: true
        }),
        throttlingBurstLimit: 200,
        throttlingRateLimit: 100
      },
      endpointConfiguration: { types: [apigw.EndpointType.REGIONAL] }
    });

    const items = api.root.addResource('items', {
      defaultCorsPreflightOptions: {
        allowOrigins: apigw.Cors.ALL_ORIGINS,
        allowMethods: ['GET', 'POST', 'DELETE', 'OPTIONS'],
        allowHeaders: ['Content-Type', 'X-Amz-Date', 'Authorization', 'X-Api-Key']
      }
    });

    items.addMethod('GET', new apigw.LambdaIntegration(getFn, { proxy: true }), {
      apiKeyRequired: false
    });
    items.addMethod('POST', new apigw.LambdaIntegration(postFn, { proxy: true }), {
      apiKeyRequired: false
    });

    const itemById = items.addResource('{id}');
    itemById.addMethod('GET', new apigw.LambdaIntegration(getFn, { proxy: true }), {
      apiKeyRequired: false
    });
    itemById.addMethod('DELETE', new apigw.LambdaIntegration(deleteFn, { proxy: true }), {
      apiKeyRequired: false
    });

    new CfnOutput(this, 'ApiEndpoint', { value: api.url ?? '' });
    new CfnOutput(this, 'TableName', { value: table.tableName });
  }
}