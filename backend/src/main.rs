use aws_config::meta::region::RegionProviderChain;
use aws_config::BehaviorVersion;
use aws_sdk_dynamodb::types::{AttributeValue, ReturnValue};
use lambda_http::{run, service_fn, tracing, Body, Error, Request, RequestExt, Response};
use serde::{Deserialize, Serialize};
use serde_dynamo::aws_sdk_dynamodb_1::from_item;
use serde_dynamo::to_item;
use std::collections::HashMap;
use std::env;
use std::fmt::format;
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
    members: HashMap<String, u16>,
}

async fn create_room(config: &HandlerConfig) -> Result<Response<Body>, Error> {
    let uuid = Uuid::new_v4();
    let poker_room = PokerRoom {
        id: uuid.to_string(),
        revealed: false,
        members: HashMap::new(),
    };

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

async fn join_room(config: &HandlerConfig, room_uuid: &str, user: &str) -> Result<Response<Body>, Error> {
    let update_result = config
        .dynamodb_client
        .update_item()
        .table_name(config.table_name.as_str())
        .key("Id", AttributeValue::S(room_uuid.to_string()))
        .update_expression("set Members.#Username = :value")
        .expression_attribute_names("#Username", user.to_string())
        .expression_attribute_values(":value", AttributeValue::N("0".to_string()))
        .return_values(ReturnValue::AllNew)
        .send()
        .await?;

    let attributes = update_result.attributes().unwrap();
    let response: PokerRoom = from_item(attributes.clone())?;
    ok(response)
}

async fn exit_room(config: &HandlerConfig, room_uuid: &str, user: &str) -> Result<Response<Body>, Error> {
    let update_result = config
        .dynamodb_client
        .update_item()
        .table_name(config.table_name.as_str())
        .key("Id", AttributeValue::S(room_uuid.to_string()))
        .update_expression("remove Members.#Username")
        .expression_attribute_names("#Username", user.to_string())
        .return_values(ReturnValue::AllNew)
        .send()
        .await?;

    let attributes = update_result.attributes().unwrap();
    let response: PokerRoom = from_item(attributes.clone())?;
    ok(response)
}

async fn cast_vote(config: &HandlerConfig, room_uuid: &str, user: &str, vote: &str) -> Result<Response<Body>, Error> {
    let update_result = config
        .dynamodb_client
        .update_item()
        .table_name(config.table_name.as_str())
        .key("Id", AttributeValue::S(room_uuid.to_string()))
        .update_expression("set Members.#Username = :value")
        .expression_attribute_names("#Username", user.to_string())
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
    let update_result = config
        .dynamodb_client
        .update_item()
        .table_name(config.table_name.as_str())
        .key("Id", AttributeValue::S(room_uuid.to_string()))
        .update_expression("set Revealed = :value")
        .expression_attribute_values(":value", AttributeValue::Bool(false))
        .return_values(ReturnValue::AllNew)
        .send()
        .await?;

    let attributes = update_result.attributes().unwrap();
    let response: PokerRoom = from_item(attributes.clone())?;
    ok(response)
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
async fn function_handler(config: &HandlerConfig, request: Request) -> Result<Response<Body>, Error> {
    let uri = request.uri().path();
    let method = request.method().as_str();
    let room_id = request
        .query_string_parameters_ref()
        .and_then(|params| params.first("id"));
    let user = request
        .query_string_parameters_ref()
        .and_then(|params| params.first("user"));
    let vote = request
        .query_string_parameters_ref()
        .and_then(|params| params.first("vote"));

    match (method, uri) {
        ("POST", "/room") => create_room(config).await,
        ("POST", "/room/join") => join_room(config, room_id.unwrap(), user.unwrap()).await,
        ("POST", "/room/vote") => cast_vote(config, room_id.unwrap(), user.unwrap(), vote.unwrap()).await,
        ("POST", "/room/reveal") => reveal(config, room_id.unwrap()).await,
        ("POST", "/room/reset") => reset(config, room_id.unwrap()).await,
        ("POST", "/room/leave") => exit_room(config, room_id.unwrap(), user.unwrap()).await,
        ("GET", "/room") => get_room(config, room_id.unwrap()).await,
        _ => not_found(uri)
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
    })).await
}
