module Room exposing (..)

import Http exposing (Error)
import Json.Decode as Decode exposing (Decoder, bool, field, int, string)


type alias Room =
    { user : User
    , id : String
    , revealed : Bool
    , members : List UserVote
    }


type alias User =
    { id : String
    , name : String
    }


type alias UserVote =
    { user : User
    , vote : Int
    , ping : Int
    }


type alias VoteInfo =
    { id : String
    , name : String
    , vote : Int
    , ping : Int
    }


urlAddress apiUrl part =
    apiUrl ++ "room" ++ part


create : String -> User -> (Result Error Room -> msg) -> Cmd msg
create apiUrl user event =
    Http.post
        { url = urlAddress apiUrl "?user=" ++ user.name ++ "&userId=" ++ user.id
        , body = Http.emptyBody
        , expect = Http.expectJson event (roomDecoder (Room user))
        }


ping : String -> String -> User -> (Result Error Room -> msg) -> Cmd msg
ping apiUrl roomId user event =
    Http.post
        { url = urlAddress apiUrl "/ping?id=" ++ roomId ++ "&userId=" ++ user.id
        , body = Http.emptyBody
        , expect = Http.expectJson event (roomDecoder (Room user))
        }


join : String -> Maybe String -> User -> (Result Error Room -> m) -> Cmd m
join apiUrl roomId user event =
    case roomId of
        Nothing ->
            create apiUrl user event

        Just id ->
            Http.post
                { url = urlAddress apiUrl "/join?id=" ++ id ++ "&user=" ++ user.name ++ "&userId=" ++ user.id
                , body = Http.emptyBody
                , expect = Http.expectJson event (roomDecoder (Room user))
                }


castVote apiUrl room vote event =
    Http.post
        { url = urlAddress apiUrl ("/vote?id=" ++ room.id ++ "&userId=" ++ room.user.id ++ "&vote=" ++ String.fromInt vote)
        , body = Http.emptyBody
        , expect = Http.expectJson event (roomDecoder (Room room.user))
        }


reveal apiUrl room event =
    Http.post
        { url = urlAddress apiUrl "/reveal?id=" ++ room.id
        , body = Http.emptyBody
        , expect = Http.expectJson event (roomDecoder (Room room.user))
        }


leave : String -> String -> User -> (Result Error Room -> msg) -> Cmd msg
leave apiUrl roomId user event =
    Http.post
        { url = urlAddress apiUrl "/leave?id=" ++ roomId ++ "&userId=" ++ user.id
        , body = Http.emptyBody
        , expect = Http.expectJson event (roomDecoder (Room user))
        }


reset apiUrl room event =
    Http.post
        { url = urlAddress apiUrl "/reset?id=" ++ room.id
        , body = Http.emptyBody
        , expect = Http.expectJson event (roomDecoder (Room room.user))
        }


roomDecoder a =
    Decode.map3 a
        (field "Id" string)
        (field "Revealed" bool)
        (field "Members" membersDecoder)


membersDecoder : Decoder (List UserVote)
membersDecoder =
    Decode.keyValuePairs memberInfoDecoder |> Decode.map toMembers


memberInfoDecoder : Decoder VoteInfo
memberInfoDecoder =
    Decode.map4 VoteInfo
        (field "Id" string)
        (field "Name" string)
        (field "Vote" int)
        (field "Ping" int)


toMembers : List ( String, VoteInfo ) -> List UserVote
toMembers =
    List.map toMember


toMember : ( String, VoteInfo ) -> UserVote
toMember m =
    UserVote (User (Tuple.first m) (Tuple.second m).name) (Tuple.second m).vote (Tuple.second m).ping
