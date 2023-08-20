module Room exposing (..)

import Dict exposing (Dict)
import Http
import Json.Decode as Decode exposing (field, int, list, string)
import Json.Encode as Encode


type alias Room =
    { id : String
    , name : String
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


emptyRoom =
    Room "" "" Nothing []


urlAddress part =
    "https://zduined56k.execute-api.eu-west-1.amazonaws.com" ++ part


createRoom roomname event =
    Http.post
        { url = urlAddress "/rooms"
        , body = Http.jsonBody (nameEncoder roomname)
        , expect = Http.expectJson event (roomDecoder Room)
        }


nameEncoder username =
    Encode.object
        [ ( "name", Encode.string username )
        ]


roomDecoder a =
    Decode.map4 a
        (field "id" string)
        (field "name" string)
        (Decode.maybe (field "cardToVote" cardDecoder))
        (field "cards" (list cardDecoder))


cardDecoder =
    Decode.map3 Card
        (field "id" string)
        (field "name" string)
        (field "votes" (Decode.dict int))
