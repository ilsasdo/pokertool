import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
    DynamoDBDocumentClient,
    ScanCommand,
    PutCommand,
    UpdateCommand,
    GetCommand,
    DeleteCommand,
} from "@aws-sdk/lib-dynamodb";
import { randomUUID } from 'crypto';

const client = new DynamoDBClient({});

const dynamo = DynamoDBDocumentClient.from(client);
const tableName = "pokertool";

export const loadRoom = async (event, context) => {
    try {
        let output = await dynamo.send(
            new GetCommand({
                TableName: tableName,
                Key: {
                    id: event.pathParameters.id,
                },
            })
        );

        return {
            'statusCode': 200,
            'body': JSON.stringify(output.Item)
        }
    } catch (err) {
        return err;
    }
}

export const joinRoom = async (event, context) => {
    try {
        let request = JSON.parse(event.body);
        await dynamo.send(
            new UpdateCommand({
                TableName: tableName,
                Key: {
                    id: event.pathParameters.id,
                },
                UpdateExpression: "SET partecipants = list_append(partecipants, :partecipant)",
                ExpressionAttributeValues: {
                    ":partecipant": [request.username],
                }
            })
        );

        let output = await dynamo.send(
            new GetCommand({
                TableName: tableName,
                Key: {
                    id: event.pathParameters.id,
                },
            })
        );

        return {
            'statusCode': 200,
            'body': JSON.stringify(output.Item)
        }
    } catch (err) {
        return err;
    }
}

export const createRoom = async (event, context) => {
    try {
        let requestJSON = JSON.parse(event.body);
        let room = {
            id: randomUUID(),
            name: requestJSON.name,
            rootUser: requestJSON.username,
            partecipants: [requestJSON.username],
            cards: []
        };

        await dynamo.send(
            new PutCommand({
                TableName: tableName,
                Item: room,
            })
        );

        return {
            'statusCode': 200,
            'body': JSON.stringify(room)
        }
    } catch (err) {
        return err;
    }
}
