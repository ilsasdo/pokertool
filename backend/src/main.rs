use aws_config::meta::region::RegionProviderChain;
use aws_config::BehaviorVersion;
use aws_sdk_dynamodb::types::{AttributeValue, ReturnValue};
use lambda_http::{run, service_fn, tracing, Body, Error, Request, RequestExt, Response};
use serde::{Deserialize, Serialize};
use serde_dynamo::aws_sdk_dynamodb_1::from_item;
use serde_dynamo::{to_attribute_value, to_item};
use std::collections::HashMap;
use std::env;
use std::time::{SystemTime, UNIX_EPOCH};
use uuid::Uuid;

struct HandlerConfig {
    table_name: String,
    dynamodb_client: aws_sdk_dynamodb::Client,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct PokerRoom {
    id: String,
    revealed: bool,
    members: HashMap<String, Member>,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct Member {
    id: String,
    name: String,
    vote: u16,
    ping: u64,
}

async fn create_room(
    config: &HandlerConfig,
    user: Option<&str>,
    user_id: Option<&str>,
) -> Result<Response<Body>, Error> {
    let uuid = Uuid::new_v4();
    let mut poker_room = PokerRoom {
        id: uuid.to_string(),
        revealed: false,
        members: HashMap::new(),
    };

    if user.is_some() && user_id.is_some() {
        let user_vote = Member {
            id: user_id.unwrap().to_string(),
            name: user.unwrap().to_string(),
            vote: 0,
            ping: millis_since_epoch(),
        };
        poker_room.members.insert(user_vote.id.clone(), user_vote);
    }

    let item = to_item(&poker_room).unwrap();

    config
        .dynamodb_client
        .put_item()
        .table_name(config.table_name.as_str())
        .set_item(Some(item))
        .send()
        .await?;

    ok(poker_room)
}

async fn join_room(
    config: &HandlerConfig,
    room_uuid: &str,
    user: &str,
    user_id: &str,
) -> Result<Response<Body>, Error> {
    let mut map = HashMap::<String, AttributeValue>::new();
    map.insert("Id".to_string(), AttributeValue::S(user_id.to_string()));
    map.insert("Name".to_string(), AttributeValue::S(user.to_string()));
    map.insert("Vote".to_string(), AttributeValue::N("0".to_string()));
    map.insert("Ping".to_string(), AttributeValue::N(millis_since_epoch().to_string()));

    let update_result = config
        .dynamodb_client
        .update_item()
        .table_name(config.table_name.as_str())
        .key("Id", AttributeValue::S(room_uuid.to_string()))
        .update_expression("set Members.#UserId = if_not_exists(Members.#UserId, :value)")
        .expression_attribute_names("#UserId", user_id.to_string())
        .expression_attribute_values(":value", AttributeValue::M(map))
        .return_values(ReturnValue::AllNew)
        .send()
        .await?;

    let attributes = update_result.attributes().unwrap();
    let response: PokerRoom = from_item(attributes.clone())?;
    ok(response)
}

fn millis_since_epoch() -> u64 {
    let start = SystemTime::now();
    let since_the_epoch = start
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards");
    return since_the_epoch.as_secs();
}

async fn exit_room(
    config: &HandlerConfig,
    room_uuid: &str,
    user_id: &str,
) -> Result<Response<Body>, Error> {
    let update_result = config
        .dynamodb_client
        .update_item()
        .table_name(config.table_name.as_str())
        .key("Id", AttributeValue::S(room_uuid.to_string()))
        .update_expression("remove Members.#UserId")
        .expression_attribute_names("#UserId", user_id.to_string())
        .return_values(ReturnValue::AllNew)
        .send()
        .await?;

    let attributes = update_result.attributes().unwrap();
    let response: PokerRoom = from_item(attributes.clone())?;
    ok(response)
}

async fn cast_vote(
    config: &HandlerConfig,
    room_uuid: &str,
    user_id: &str,
    vote: &str,
) -> Result<Response<Body>, Error> {
    let update_result = config
        .dynamodb_client
        .update_item()
        .table_name(config.table_name.as_str())
        .key("Id", AttributeValue::S(room_uuid.to_string()))
        .update_expression("set Members.#UserId.Vote = :value")
        .expression_attribute_names("#UserId", user_id.to_string())
        .expression_attribute_values(":value", AttributeValue::N(vote.to_string()))
        .return_values(ReturnValue::AllNew)
        .send()
        .await?;

    let attributes = update_result.attributes().unwrap();
    let response: PokerRoom = from_item(attributes.clone())?;
    ok(response)
}

async fn reveal(config: &HandlerConfig, room_uuid: &str) -> Result<Response<Body>, Error> {
    let update_result = config
        .dynamodb_client
        .update_item()
        .table_name(config.table_name.as_str())
        .key("Id", AttributeValue::S(room_uuid.to_string()))
        .update_expression("set Revealed = :value")
        .expression_attribute_values(":value", AttributeValue::Bool(true))
        .return_values(ReturnValue::AllNew)
        .send()
        .await?;

    let attributes = update_result.attributes().unwrap();
    let response: PokerRoom = from_item(attributes.clone())?;
    ok(response)
}

async fn reset(config: &HandlerConfig, room_uuid: &str) -> Result<Response<Body>, Error> {
    let get_result = config
        .dynamodb_client
        .get_item()
        .table_name(config.table_name.as_str())
        .key("Id", AttributeValue::S(room_uuid.to_string()))
        .send()
        .await?;

    let attributes = get_result.item.unwrap();
    let room: PokerRoom = from_item(attributes.clone())?;

    let new_room: PokerRoom = PokerRoom {
        id: room.id,
        revealed: false,
        members: room.members.iter().fold(HashMap::new(), |mut acc, (key, value) | {
            acc.insert(key.to_string(), Member {
                id: value.id.to_string(),
                name: value.name.to_string(),
                vote: 0,
                ping: millis_since_epoch(),
            });
            acc
        })
    };

    let item = to_item(&new_room)?;
    config
        .dynamodb_client
        .put_item()
        .table_name(config.table_name.as_str())
        .set_item(Some(item))
        .send()
        .await?;

    ok(new_room)
}

async fn get_room(config: &HandlerConfig, room_uuid: &str) -> Result<Response<Body>, Error> {
    let get_result = config
        .dynamodb_client
        .get_item()
        .table_name(config.table_name.as_str())
        .key("Id", AttributeValue::S(room_uuid.to_string()))
        .send()
        .await?;

    let attributes = get_result.item.unwrap();
    let response: PokerRoom = from_item(attributes.clone())?;
    ok(response)
}

async fn ping_room(
    config: &HandlerConfig,
    room_uuid: &str,
    user_id: &str,
) -> Result<Response<Body>, Error> {
    let update_result = config
        .dynamodb_client
        .update_item()
        .table_name(config.table_name.as_str())
        .key("Id", AttributeValue::S(room_uuid.to_string()))
        .update_expression("set Members.#UserId.Ping = :value")
        .expression_attribute_names("#UserId", user_id.to_string())
        .expression_attribute_values(":value", AttributeValue::N(millis_since_epoch().to_string()))
        .return_values(ReturnValue::AllNew)
        .send()
        .await?;

    let attributes = update_result.attributes().unwrap();
    let response: PokerRoom = from_item(attributes.clone())?;
    ok(response)
}

fn not_found(uri: &str) -> Result<Response<Body>, Error> {
    let body = format!("Not found: {}", uri);
    let resp = Response::builder()
        .status(404)
        .header("content-type", "text/html")
        .body(body.into())
        .map_err(Box::new)?;
    Ok(resp)
}

fn ok(message: PokerRoom) -> Result<Response<Body>, Error> {
    let json = serde_json::to_string(&message).map_err(Box::new)?;
    let resp = Response::builder()
        .status(200)
        .header("content-type", "text/json")
        .body(json.into())
        .map_err(Box::new)?;
    Ok(resp)
}

/// This is the main body for the function.
/// Write your code inside it.
/// There are some code example in the following URLs:
/// - https://github.com/awslabs/aws-lambda-rust-runtime/tree/main/examples
async fn function_handler(
    config: &HandlerConfig,
    request: Request,
) -> Result<Response<Body>, Error> {
    let uri = request.uri().path();
    let method = request.method().as_str();
    let room_id = request
        .query_string_parameters_ref()
        .and_then(|params| params.first("id"));
    let user = request
        .query_string_parameters_ref()
        .and_then(|params| params.first("user"));
    let user_id = request
        .query_string_parameters_ref()
        .and_then(|params| params.first("userId"));
    let vote = request
        .query_string_parameters_ref()
        .and_then(|params| params.first("vote"));

    match (method, uri) {
        ("POST", "/room") => create_room(config, user, user_id).await,
        ("POST", "/room/join") => {
            join_room(config, room_id.unwrap(), user.unwrap(), user_id.unwrap()).await
        }
        ("POST", "/room/vote") => {
            cast_vote(config, room_id.unwrap(), user_id.unwrap(), vote.unwrap()).await
        }
        ("POST", "/room/reveal") => reveal(config, room_id.unwrap()).await,
        ("POST", "/room/reset") => reset(config, room_id.unwrap()).await,
        ("POST", "/room/leave") => exit_room(config, room_id.unwrap(), user_id.unwrap()).await,
        ("POST", "/room/ping") => ping_room(config, room_id.unwrap(), user_id.unwrap()).await,
        ("GET", "/room") => get_room(config, room_id.unwrap()).await,
        _ => not_found(uri),
    }
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    tracing::init_default_subscriber();

    let region_provider = RegionProviderChain::default_provider();
    let config = aws_config::defaults(BehaviorVersion::latest())
        .region(region_provider)
        .load()
        .await;

    let table_name = env::var("TABLE_NAME").expect("TABLE_NAME environment variable is not set");
    let dynamodb_client = aws_sdk_dynamodb::Client::new(&config);

    let config = &HandlerConfig {
        table_name,
        dynamodb_client,
    };

    run(service_fn(move |event| async move {
        function_handler(config, event).await
    }))
    .await
}
