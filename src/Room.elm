module Room exposing (..)

import Http
import Json.Decode as Decode exposing (Decoder, bool, dict, field, int, keyValuePairs, list, string)
import Json.Encode as Encode


type alias Room =
    { id : String
    , revealed : Bool
    , members : List ( String, Int )
    }


type alias Member =
    { username : String
    , vote : Int
    }


urlAddress part =
    "/room" ++ part


create event =
    Http.post
        { url = urlAddress ""
        , body = Http.emptyBody
        , expect = Http.expectJson event (roomDecoder Room)
        }


roomDecoder a =
    Decode.map3 a
        (field "Id" string)
        (field "Revealed" bool)
        (field "Members" (keyValuePairs int))
