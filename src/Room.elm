module Room exposing (..)

import Dict exposing (Dict)
import Http
import Json.Decode as Decode exposing (field, int, list, string)
import Json.Encode as Encode


type alias Room =
    { id : String
    , name : String
    , rootUser : Username
    , partecipants : List Username
    , cardToVote : Maybe Card
    , cards : List Card
    }


isEmptyRoom room =
    room.id == "" && room.name == ""


type alias Card =
    { id : String
    , name : String
    , votes : Dict Username Int
    }


type alias Username =
    String


urlAddress part =
    "https://zduined56k.execute-api.eu-west-1.amazonaws.com" ++ part


createRoom roomname username event =
    Http.post
        { url = urlAddress "/rooms"
        , body = Http.jsonBody (createRoomEncoder roomname username)
        , expect = Http.expectJson event (roomDecoder Room)
        }


joinRoom roomId username event =
    Http.post
        { url = urlAddress "/rooms/" ++ roomId ++ "/join"
        , body = Http.jsonBody (joinRoomEncoder username)
        , expect = Http.expectJson event (roomDecoder Room)
        }


loadRoom roomId event =
    Http.get
        { url = urlAddress ("/rooms/" ++ roomId)
        , expect = Http.expectJson event (roomDecoder Room)
        }


createRoomEncoder roomname username =
    Encode.object
        [ ( "name", Encode.string roomname )
        , ( "username", Encode.string username )
        ]


joinRoomEncoder username =
    Encode.object
        [ ( "username", Encode.string username )
        ]


roomDecoder a =
    Decode.map6 a
        (field "id" string)
        (field "name" string)
        (field "rootUser" string)
        (field "partecipants" (list string))
        (Decode.maybe (field "cardToVote" cardDecoder))
        (field "cards" (list cardDecoder))


cardDecoder =
    Decode.map3 Card
        (field "id" string)
        (field "name" string)
        (field "votes" (Decode.dict int))


addCard : String -> Room -> Room
addCard cardname room =
    { room | cards = room.cards ++ [ Card "id" cardname Dict.empty ] }


selectCard : Card -> Room -> Room
selectCard card room =
    { room | cardToVote = Just card }


castVote : Card -> Username -> Int -> Room -> Room
castVote card user vote room =
    let
        votedCard =
            { card | votes = Dict.insert user vote card.votes }
    in
    { room
        | cardToVote = Just votedCard
        , cards = replaceCard votedCard room.cards
    }


replaceCard card cards =
    cards
        |> List.map
            (\c ->
                if c.name == card.name then
                    card

                else
                    c
            )
