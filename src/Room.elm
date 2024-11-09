module Room exposing (..)

import Http exposing (Error)
import Json.Decode as Decode exposing (Decoder, bool, field, int, string)


type alias Room =
    { user : String
    , id : String
    , revealed : Bool
    , members : List Member
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


reveal roomId user event =
    Http.post
        { url = urlAddress "/reveal?id=" ++ roomId
        , body = Http.emptyBody
        , expect = Http.expectJson event (roomDecoder (Room user))
        }


reset roomId user event =
    Http.post
        { url = urlAddress "/reset?id=" ++ roomId
        , body = Http.emptyBody
        , expect = Http.expectJson event (roomDecoder (Room user))
        }


roomDecoder a =
    Decode.map3 a
        (field "Id" string)
        (field "Revealed" bool)
        (field "Members" membersDecoder)


membersDecoder : Decoder (List Member)
membersDecoder =
    Decode.keyValuePairs int |> Decode.map toMembers


toMembers : List ( String, Int ) -> List Member
toMembers =
    List.map toMember


toMember : ( String, Int ) -> Member
toMember m =
    Member (Tuple.first m) (Tuple.second m)
