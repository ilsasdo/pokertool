import {DynamoDBClient} from "@aws-sdk/client-dynamodb";
import {
    DynamoDBDocumentClient,
    PutCommand,
    ScanCommand,
    DeleteCommand,
    UpdateCommand
} from "@aws-sdk/lib-dynamodb";
import { unmarshall } from '@aws-sdk/util-dynamodb'
import {ApiGatewayManagementApiClient, PostToConnectionCommand} from '@aws-sdk/client-apigatewaymanagementapi';

const client = new DynamoDBClient({});

const dynamo = DynamoDBDocumentClient.from(client);
const tableName = "pokertool_connections";

export const connectHandler = async (event, context) => {
    console.log("COLLEGATO: ")
    console.log(`ConnectionId: ${event.requestContext.connectionId}`)

    let roomConnection = {
        connectionId: event.requestContext.connectionId
    };

    await dynamo.send(
        new PutCommand({
            TableName: tableName,
            Item: roomConnection
        })
    );

    return {
        'statusCode': 200,
        'body': "connected"
    }
}

export const disconnectHandler = async (event, context) => {
    console.log("DISCONNECTED: ")
    console.log(`ConnectionId: ${event.requestContext.connectionId}`)

    await dynamo.send(
        new DeleteCommand({
            TableName: tableName,
            Key: {
                ConnectionId: event.requestContext.connectionId,
            }
        })
    );

    return { statusCode: 200, body: 'Disconnected.' };
}

export const sendmessageHandler = async (event, context) => {
    console.log("MESSAGE HANDLER: ")
    console.log(`ConnectionId: ${event.requestContext.connectionId}`)
    console.log(`event: %j`, event)
    console.log(`context: %j`, context)

    let body = JSON.parse(event.body)

    switch (body.payload.type) {
        case "join":
            return joinRoom(event.requestContext.connectionId, body.payload.roomId)

        default:
            return { statusCode: 404, body: `Unknown Payload Type ${body.payload.type}` };
    }
}

async function joinRoom(connectionId, roomId) {
    await dynamo.send(
        new UpdateCommand({
            TableName: tableName,
            Key: {
                connectionId: connectionId,
            },
            UpdateExpression: "SET roomId = :roomId",
            ExpressionAttributeValues: {
                ":roomId": roomId
            }
        })
    );

    return { statusCode: 200, body: 'Room joined.' }
}

export const streamUpdate = async (event, context) => {
    console.log("STREAM UPDATE!")

    const client = new ApiGatewayManagementApiClient({});
    const input = { // PostToConnectionRequest
        Data: "BLOB_VALUE", // required
        ConnectionId: "STRING_VALUE", // required
    };
    const command = new PostToConnectionCommand(input);
    const response = await client.send(command);

    event.Records.forEach(function(record) {
        console.log(record.eventID);
        console.log(record.eventName);
        console.log('DynamoDB Record: %j', record.dynamodb);
        console.log('DynamoDB Record: %j', unmarshall(record.dynamodb));

        // for each record received,
        // retrieve all connectionIds given roomId
        // send new data to all connectionIds.
        pushMessage(unmarshall(record.dynamodb))

    });

    return {
        statusCode: 200, body: "stream updated"
    }
}


const pushMessage = async (room) => {
    let connections = await dynamo.send(
        new ScanCommand({
            TableName: tableName,
            ProjectionExpression: 'connectionId',
            FilterExpression: "roomId = :roomId",
            ExpressionAttributeValues: {
                ":roomId": room.id
            }
        })
    );

    console.log(`Connection ids: ${connections} `)

    return {statusCode: 200, body: 'Event sent.'};
}
