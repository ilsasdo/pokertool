import {DynamoDBClient} from "@aws-sdk/client-dynamodb";
import {DynamoDBDocumentClient, GetCommand, PutCommand, UpdateCommand,} from "@aws-sdk/lib-dynamodb";
import {randomUUID} from 'crypto';

const client = new DynamoDBClient({});

const dynamo = DynamoDBDocumentClient.from(client);
const tableName = "pokertool";

const loadRoom = async (event, context) => {
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
}

const joinRoom = async (event, context) => {
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
}

const addCard = async (event, context) => {
    let request = JSON.parse(event.body);
    await dynamo.send(
        new UpdateCommand({
            TableName: tableName,
            Key: {
                id: event.pathParameters.id,
            },
            UpdateExpression: "SET cards = list_append(cards, :card)",
            ExpressionAttributeValues: {
                ":card": [{id: randomUUID(), name: request.name, votes: {}}],
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
}

const castVote = async (event, context) => {
    let request = JSON.parse(event.body);
    let cardIndex = request.cardIndex;
    let username = request.username;
    let vote = request.vote;

    await dynamo.send(
        new UpdateCommand({
            TableName: tableName,
            Key: {
                id: event.pathParameters.id,
            },
            UpdateExpression: "SET cards[" + cardIndex + "].votes.#username = :vote",
            ExpressionAttributeNames: {
                "#username": username
            },
            ExpressionAttributeValues: {
                ":vote": vote
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
}

const selectCard = async (event, context) => {
    let request = JSON.parse(event.body);
    let cardId = request.cardId;

    await dynamo.send(
        new UpdateCommand({
            TableName: tableName,
            Key: {
                id: event.pathParameters.id,
            },
            UpdateExpression: "SET selectedCard = :cardId",
            ExpressionAttributeValues: {
                ":cardId": cardId
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
}

const createRoom = async (event, context) => {
    let requestJSON = JSON.parse(event.body);
    let room = {
        id: randomUUID(),
        name: requestJSON.name,
        rootUser: requestJSON.username,
        partecipants: [requestJSON.username],
        selectedCard: null,
        cards: [],
        connectionIds: []
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
}

export const requestHandler = async (event, context) => {
    try {
        switch (event.routeKey) {
            case "POST /rooms":
                return createRoom(event, context);

            case "POST /rooms/{id}/join":
                return joinRoom(event, context);

            case "GET /rooms/{id}":
                return loadRoom(event, context);

            case "POST /rooms/{id}/addCard":
                return addCard(event, context);

            case "POST /rooms/{id}/selectCard":
                return selectCard(event, context);

            case "POST /rooms/{id}/castVote":
                return castVote(event, context);

            default:
                return {
                    statusCode: 404,
                    body: `Operation "${event.routeKey}" not supported.`
                }
        }

    } catch (e) {
        console.log(e);
        return e
    }
}
