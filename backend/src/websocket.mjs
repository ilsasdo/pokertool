import {DynamoDBClient} from "@aws-sdk/client-dynamodb";
import {DeleteCommand, DynamoDBDocumentClient, PutCommand, ScanCommand} from "@aws-sdk/lib-dynamodb";
// import {ApiGatewayManagementApi} from 'aws-sdk/apis/webso'

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
    return { statusCode: 200, body: 'Disconnected.' };
}

export const messageHandler = async (event, context) => {
    console.log("MESSAGE HANDLER: ")
    console.log(`ConnectionId: ${event.requestContext.connectionId}`)
    return { statusCode: 200, body: 'Message Sent.' };
}

export const streamUpdate = async (event, context) => {
    console.log("STREAM UPDATE!")

    event.Records.forEach(function(record) {
        console.log(record.eventID);
        console.log(record.eventName);
        console.log('DynamoDB Record: %j', record.dynamodb);
    });

    return {
        statusCode: 200, body: "stream updated"
    }
}

const joinRoom = async (event, context) => {
    let roomConnection = {
        id: event.requestContext.connectionId
        , roomId: event.pathParameters.id
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

const quitRoom = async (event, context) => {
    await dynamo.send(
        new DeleteCommand({
            TableName: tableName,
            Key: {
                ConnectionId: event.requestContext.connectionId,
            }
        })
    );

    return {
        'statusCode': 200,
        'body': "connection closed"
    }
}

const pushMessage = async (event, context) => {
    let connections = await dynamo.send(
        new ScanCommand({
            TableName: tableName,
            ProjectionExpression: 'id',
            FilterExpression: "roomId = :roomId",
            ExpressionAttributeValues: {
                ":roomId": event.pathParameters.id
            }
        })
    );

    console.log(`Event: ${event}`)

    const api = new ApiGatewayManagementApi({
        // endpoint: process.env.ENDPOINT,
    });

    const postCalls = connections.Items.map(async ({Id}) => {
        await api.postToConnection({ConnectionId: Id, Data: JSON.stringify(event)}).promise();
    });

    await Promise.all(postCalls);

    return {statusCode: 200, body: 'Event sent.'};
}
