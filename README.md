# docs

https://github.com/aws/serverless-application-model/blob/master/versions/2016-10-31.md#aws-serverless-application-model-sam

https://betterprogramming.pub/aws-sam-setting-local-serverless-development-with-lambda-and-dynamodb-5b4c7375f813

# startup local dynamodb

1. `docker run -p 8000:8000 amazon/dynamodb-local`
2. create local table: `aws dynamodb create-table --table-name pokertool --attribute-definitions AttributeName=id,AttributeType=S --key-schema AttributeName=id,KeyType=HASH --billing-mode PAY_PER_REQUEST --endpoint-url http://localhost:8000`
3. list table content: `aws dynamodb execute-statement --statement "SELECT * FROM pokertool" --endpoint-url http://localhost:8000`


invoke local function with:

`DOCKER_HOST="unix://$HOME/.colima/docker.sock" sam local invoke createRoom`

# run project with

`./rundev.sh`



# roadmap

1. as soon the user opens the page: he must set his/her name.
2. then the user can create a new "room"
3. share the link of the new room
4. when a user enters on a shared room, he is requested to insert his name then connects to the selected room.
5. every user can see other users in the room
6. the user who creates the room can add a new card to estimate by giving the card a name
7. all the users are then provided the name of the card to estimate and are presented with some values
8. each user can select one value
9. every user can see who has voted
10. when the root user wants, can reveal all the cards.
11. every user now see the cards values from others.
