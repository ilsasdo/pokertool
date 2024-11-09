module Room exposing (..)

import Http exposing (Error)
import Json.Decode as Decode exposing (Decoder, bool, dict, field, int, keyValuePairs, list, string)
import Json.Encode as Encode


type alias Room =
    { user : String
    , id : String
    , revealed : Bool
    , members : List ( String, Int )
    }


type alias Member =
    { username : String
    , vote : Int
    }


urlAddress part =
    "/room" ++ part


create user event =
    Http.post
        { url = urlAddress "?user=" ++ user
        , body = Http.emptyBody
        , expect = Http.expectJson event (roomDecoder (Room user))
        }


join : Maybe String -> String -> (Result Error Room -> m) -> Cmd m
join roomId user event =
    case roomId of
        Nothing ->
            create user event

        Just id ->
            Http.post
                { url = urlAddress "/join?id=" ++ id ++ "&user=" ++ user
                , body = Http.emptyBody
                , expect = Http.expectJson event (roomDecoder (Room user))
                }


castVote roomId user vote event =
    Http.post
        { url = urlAddress "/vote?id=" ++ roomId ++ "&user=" ++ user ++ "&vote=" ++ String.fromInt vote
        , body = Http.emptyBody
        , expect = Http.expectJson event (roomDecoder (Room user))
        }


roomDecoder a =
    Decode.map3 a
        (field "Id" string)
        (field "Revealed" bool)
        (field "Members" (keyValuePairs int))
