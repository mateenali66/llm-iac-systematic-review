import * as cdk from 'aws-cdk-lib';
import { Stack, StackProps, Duration, RemovalPolicy, Size } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigw from 'aws-cdk-lib/aws-apigateway';
import * as logs from 'aws-cdk-lib/aws-logs';

export class ItemsApiStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const table = new dynamodb.Table(this, 'ItemsTable', {
      tableName: 'ItemsCatalog',
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      pointInTimeRecovery: true,
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
      removalPolicy: RemovalPolicy.RETAIN
    });

    const commonLambdaProps: Omit<lambda.FunctionProps, 'code' | 'handler'> = {
      runtime: lambda.Runtime.NODEJS_18_X,
      architecture: lambda.Architecture.ARM_64,
      memorySize: 256,
      timeout: Duration.seconds(10),
      environment: {
        TABLE_NAME: table.tableName,
        PRIMARY_KEY: 'id'
      },
      logRetention: logs.RetentionDays.THREE_MONTHS,
      tracing: lambda.Tracing.ACTIVE,
      reservedConcurrentExecutions: 10
    };

    const getItemsFunction = new lambda.Function(this, 'GetItemsFunction', {
      ...commonLambdaProps,
      description: 'GET /items - list or fetch items from the catalog',
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const ddb = new AWS.DynamoDB.DocumentClient();
        const TABLE_NAME = process.env.TABLE_NAME;
        const PK = process.env.PRIMARY_KEY || 'id';

        const response = (statusCode, body) => ({
          statusCode,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          },
          body: JSON.stringify(body)
        });

        exports.handler = async (event) => {
          try {
            const q = event.queryStringParameters || {};
            if (q.id) {
              const params = { TableName: TABLE_NAME, Key: { [PK]: q.id } };
              const data = await ddb.get(params).promise();
              if (!data.Item) return response(404, { message: 'Item not found' });
              return response(200, data.Item);
            } else {
              const limit = Math.min(parseInt(q.limit || '50', 10) || 50, 200);
              let eks = undefined;
              if (q.lastEvaluatedKey) {
                try { eks = JSON.parse(q.lastEvaluatedKey); } catch (_) {}
              }
              const params = { TableName: TABLE_NAME, Limit: limit, ExclusiveStartKey: eks };
              const data = await ddb.scan(params).promise();
              return response(200, { items: data.Items || [], lastEvaluatedKey: data.LastEvaluatedKey || null });
            }
          } catch (err) {
            console.error(err);
            return response(500, { message: 'Internal server error' });
          }
        };
      `)
    });

    const postItemFunction = new lambda.Function(this, 'PostItemFunction', {
      ...commonLambdaProps,
      description: 'POST /items - create or upsert an item in the catalog',
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const ddb = new AWS.DynamoDB.DocumentClient();
        const TABLE_NAME = process.env.TABLE_NAME;
        const PK = process.env.PRIMARY_KEY || 'id';

        const response = (statusCode, body) => ({
          statusCode,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          },
          body: JSON.stringify(body)
        });

        exports.handler = async (event) => {
          try {
            if (!event.body) return response(400, { message: 'Missing request body' });
            let item;
            try { item = JSON.parse(event.body); } catch (_) { return response(400, { message: 'Invalid JSON body' }); }
            if (!item || typeof item !== 'object') return response(400, { message: 'Invalid item' });
            if (!item[PK]) return response(400, { message: \`Missing primary key: \${PK}\` });

            const params = {
              TableName: TABLE_NAME,
              Item: item,
              ConditionExpression: 'attribute_not_exists(#pk)',
              ExpressionAttributeNames: { '#pk': PK }
            };

            try {
              await ddb.put(params).promise();
              return response(201, item);
            } catch (e) {
              if (e && e.code === 'ConditionalCheckFailedException') {
                return response(409, { message: 'Item already exists' });
              }
              throw e;
            }
          } catch (err) {
            console.error(err);
            return response(500, { message: 'Internal server error' });
          }
        };
      `)
    });

    const deleteItemFunction = new lambda.Function(this, 'DeleteItemFunction', {
      ...commonLambdaProps,
      description: 'DELETE /items/{id} - delete an item by id',
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        const AWS = require('aws-sdk');
        const ddb = new AWS.DynamoDB.DocumentClient();
        const TABLE_NAME = process.env.TABLE_NAME;
        const PK = process.env.PRIMARY_KEY || 'id';

        const response = (statusCode, body) => ({
          statusCode,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          },
          body: JSON.stringify(body)
        });

        exports.handler = async (event) => {
          try {
            const id = event.pathParameters && event.pathParameters.id;
            if (!id) return response(400, { message: 'Missing path parameter: id' });

            const params = {
              TableName: TABLE_NAME,
              Key: { [PK]: id },
              ConditionExpression: 'attribute_exists(#pk)',
              ExpressionAttributeNames: { '#pk': PK }
            };

            try {
              await ddb.delete(params).promise();
              return { statusCode: 204, headers: { 'Access-Control-Allow-Origin': '*' } };
            } catch (e) {
              if (e && e.code === 'ConditionalCheckFailedException') {
                return response(404, { message: 'Item not found' });
              }
              throw e;
            }
          } catch (err) {
            console.error(err);
            return response(500, { message: 'Internal server error' });
          }
        };
      `)
    });

    table.grantReadData(getItemsFunction);
    table.grantWriteData(postItemFunction);
    table.grantWriteData(deleteItemFunction);

    const apiLogGroup = new logs.LogGroup(this, 'ApiAccessLogs', {
      retention: logs.RetentionDays.ONE_YEAR,
      removalPolicy: RemovalPolicy.DESTROY
    });

    const api = new apigw.RestApi(this, 'ItemsApi', {
      restApiName: 'ItemsCatalogApi',
      description: 'API for managing items catalog',
      endpointTypes: [apigw.EndpointType.REGIONAL],
      cloudWatchRole: true,
      minimumCompressionSize: Size.kibibytes(1),
      deployOptions: {
        stageName: 'prod',
        metricsEnabled: true,
        loggingLevel: apigw.MethodLoggingLevel.INFO,
        dataTraceEnabled: false,
        throttlingBurstLimit: 50,
        throttlingRateLimit: 100,
        accessLogDestination: new apigw.LogGroupLogDestination(apiLogGroup),
        accessLogFormat: apigw.AccessLogFormat.jsonWithStandardFields({
          caller: false,
          httpMethod: true,
          ip: true,
          protocol: true,
          requestTime: true,
          resourcePath: true,
          responseLength: true,
          status: true,
          user: false
        })
      }
    });

    const items = api.root.addResource('items');
    const itemById = items.addResource('{id}');

    const corsOptions: apigw.CorsOptions = {
      allowOrigins: apigw.Cors.ALL_ORIGINS,
      allowHeaders: ['Content-Type', 'X-Amz-Date', 'Authorization', 'X-Api-Key', 'X-Amz-Security-Token'],
      allowMethods: ['GET', 'POST', 'DELETE', 'OPTIONS'],
      maxAge: Duration.days(10)
    };
    items.addCorsPreflight(corsOptions);
    itemById.addCorsPreflight(corsOptions);

    items.addMethod('GET', new apigw.LambdaIntegration(getItemsFunction, { proxy: true }));
    items.addMethod('POST', new apigw.LambdaIntegration(postItemFunction, { proxy: true }));
    itemById.addMethod('DELETE', new apigw.LambdaIntegration(deleteItemFunction, { proxy: true }));
  }
}