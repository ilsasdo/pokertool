
export const castVote = async (event, context) => {
    return {
        'statusCode': 200,
        'body': JSON.stringify({
            message: 'cast vote',
        })
    }
}

export const selectCard = async (event, context) => {
    return {
        'statusCode': 200,
        'body': JSON.stringify({
            message: 'select card',
        })
    }
}

export const addCard = async (event, context) => {
    return {
        'statusCode': 200,
        'body': JSON.stringify({
            message: 'card added',
        })
    }
}

export const loadRoom = async (event, context) => {
    return {
        'statusCode': 200,
        'body': JSON.stringify({
            message: 'room loaded',
        })
    }
}

export const createRoom = async (event, context) => {
    return {
        'statusCode': 200,
        'body': JSON.stringify({
            message: 'room created',
        })
    }
}
