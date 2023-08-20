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

const client = new DynamoDBClient({
    // endpoint: "http://host.docker.internal:8000"
});

const dynamo = DynamoDBDocumentClient.from(client);
const tableName = "pokertool";

export const createRoom = async (event, context) => {
    try {
        // let requestJSON = JSON.parse(event.body);
        let room = {
            id: randomUUID(),
            name: "my room",
        };

        await dynamo.send(
            new PutCommand({
                TableName: tableName,
                Item: room,
            })
        );
        return {
            'statusCode': 200,
            'body': JSON.stringify({
                message: `room created: ${JSON.stringify(room)}`,
            })
        }
    } catch (err) {
        console.log(err);
        return err;
    }

}
