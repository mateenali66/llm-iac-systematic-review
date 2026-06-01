import { Stack, StackProps, RemovalPolicy } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigw from 'aws-cdk-lib/aws-apigateway';
import { NodejsFunction } from 'aws-cdk-lib/aws-lambda-nodejs';
import * as path from 'path';

export class ApiLambdaCrudStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const itemsTable = new dynamodb.Table(this, 'ItemsTable', {
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: RemovalPolicy.DESTROY,
      tableName: 'items-catalog',
    });

    const getItemsFunction = new lambda.Function(this, 'GetItemsFunction', {
        runtime: lambda.Runtime.NODEJS_18_X,
        handler: 'index.handler',
        code: lambda.Code.fromInline(`
            const { DynamoDBClient, ScanCommand, GetItemCommand } = require("@aws-sdk/client-dynamodb");
            const { marshall, unmarshall } = require("@aws-sdk/util-dynamodb");
            const client = new DynamoDBClient({});
            const tableName = process.env.TABLE_NAME;

            exports.handler = async (event) => {
                console.log('request:', JSON.stringify(event, undefined, 2));
                let body;
                let statusCode = 200;
                const headers = { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" };

                try {
                    if (event.pathParameters && event.pathParameters.id) {
                        const command = new GetItemCommand({
                            TableName: tableName,
                            Key: marshall({ id: event.pathParameters.id })
                        });
                        const { Item } = await client.send(command);
                        body = Item ? unmarshall(Item) : {};
                    } else {
                        const command = new ScanCommand({ TableName: tableName });
                        const { Items } = await client.send(command);
                        body = Items.map(item => unmarshall(item));
                    }
                } catch (e) {
                    console.error(e);
                    statusCode = 500;
                    body = { error: e.message };
                }

                return { statusCode, body: JSON.stringify(body), headers };
            };
        `),
        environment: {
            TABLE_NAME: itemsTable.tableName,
        },
    });

    const createItemFunction = new lambda.Function(this, 'CreateItemFunction', {
        runtime: