use aws_config::meta::region::RegionProviderChain;
use aws_config::BehaviorVersion;
use lambda_http::{run, service_fn, tracing, Body, Error, Request, Response};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::env;
use aws_sdk_dynamodb::types::ReturnValue;
use serde_dynamo::aws_sdk_dynamodb_1::from_item;
use serde_dynamo::to_item;
use uuid::Uuid;

struct HandlerConfig {
    table_name: String,
    dynamodb_client: aws_sdk_dynamodb::Client,
}

struct User {
    name: String,
    vote: u16
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct PokerRoom {
    id: String,
    members: HashMap<String, u16>
}

// async fn join_room(config: &HandlerConfig, request: &Request) -> Result<Response<Body>, Error> {
//     let room_uuid = request
//         .query_string_parameters_ref()
//         .and_then(|params| params.first("room"))
//         .unwrap();
//     let user = request
//         .query_string_parameters_ref()
//         .and_then(|params| params.first("user"))
//         .unwrap();
//
//     let mut new_room = HashMap::new();
//     let uuid = Uuid::new_v4();
//     new_room.insert("Id".to_string(), AttributeValue::S(uuid.to_string()));
//     new_room.insert("Members".to_string(), AttributeValue::L(vec![]));
//
//     let mut user_map = HashMap::new();
//     user_map.insert("Username".to_string(), AttributeValue::S(user.to_string()));
//     user_map.insert("Vote".to_string(), AttributeValue::N(0.to_string()));
//
//     let _update_result = config
//         .dynamodb_client
//         .update_item()
//         .table_name(config.table_name.as_str())
//         .key("Id", AttributeValue::S(room_uuid.to_string()))
//         .update_expression("set #Members = list_append(#Members, :value)")
//         .expression_attribute_names("#Members", "Members")
//         .expression_attribute_values(":value", AttributeValue::L(vec![AttributeValue::M(user_map)]))
//         .return_values(ReturnValue::AllNew)
//         .send()
//         .await?;
//
//     // let attributes = update_result.attributes().unwrap();
//
//     // let created_room = json!({
//     //     "id": attributes.get("Id").unwrap().to_string(),
//     //     "members": attributes.get("Members").to_string()
//     // });
//
//     let poker_room = PokerRoom {
//         id: "12",
//     };
//     ok("ok".to_string())
// }

async fn create_room(config: &HandlerConfig) -> Result<Response<Body>, Error> {
    let uuid = Uuid::new_v4();
    let poker_room = PokerRoom {
        id: uuid.to_string(),
        members: HashMap::new(),
    };

    let item = to_item(&poker_room).unwrap();

    let insert_result = config
        .dynamodb_client
        .put_item()
        .table_name(config.table_name.as_str())
        .set_item(Some(item))
        .send()
        .await?;

    // let attribute = insert_result.attributes().unwrap();
    // let inserted_item = from_item(attribute.clone()).unwrap();
    ok(poker_room)
}

fn not_found() -> Result<Response<Body>, Error> {
    let resp = Response::builder()
        .status(404)
        .header("content-type", "text/html")
        .body("".into())
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
async fn function_handler(config: &HandlerConfig, event: Request) -> Result<Response<Body>, Error> {
    let uri = event.uri().path();

    return match uri {
        "/create" => create_room(config).await,
        // "/join" => join_room(config, &event).await,
        // "/vote" => join_room(config, &event).await,
        // "/reveal" => join_room(config, &event).await,
        // "/room" => join_room(config, &event).await,
        _ => not_found()
    };
}

//     // Extract some useful information from the request
//     let who = event
//         .query_string_parameters_ref()
//         .and_then(|params| params.first("name"))
//         .unwrap_or("world");
//     let vote = event
//         .query_string_parameters_ref()
//         .and_then(|params| params.first("vote"))
//         .unwrap_or("1");
//     let message = format!("Hello {who}, {uri} this is an AWS Lambda HTTP request");
//
//     let mut item = HashMap::new();
//     let uuid = Uuid::new_v4();
//     item.insert("Id".to_string(), AttributeValue::S(uuid.to_string()));
//     item.insert("Name".to_string(), AttributeValue::S(who.to_owned()));
//     item.insert("Vote".to_string(), AttributeValue::N(vote.to_owned()));
//
//     let insert_result = config
//         .dynamodb_client
//         .put_item()
//         .table_name(config.table_name.as_str())
//         .set_item(Some(item))
//         .send()
//         .await?;
//
//     // Return something that implements IntoResponse.
//     // It will be serialized to the right response event automatically by the runtime
//     let resp = Response::builder()
//         .status(200)
//         .header("content-type", "text/html")
//         .body(message.into())
//         .map_err(Box::new)?;
//     Ok(resp)
// }

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
