module Room exposing (..)

import Environment exposing (..)
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


urlAddress part =
    Environment.apiUrl ++ "/room" ++ part


create : User -> (Result Error Room -> msg) -> Cmd msg
create user event =
    Http.post
        { url = urlAddress "?user=" ++ user.name ++ "&userId=" ++ user.id
        , body = Http.emptyBody
        , expect = Http.expectJson event (roomDecoder (Room user))
        }


ping : String -> User -> (Result Error Room -> msg) -> Cmd msg
ping roomId user event =
    Http.post
        { url = urlAddress "/ping?id=" ++ roomId ++ "&userId=" ++ user.id
        , body = Http.emptyBody
        , expect = Http.expectJson event (roomDecoder (Room user))
        }


join : Maybe String -> User -> (Result Error Room -> m) -> Cmd m
join roomId user event =
    case roomId of
        Nothing ->
            create user event

        Just id ->
            Http.post
                { url = urlAddress "/join?id=" ++ id ++ "&user=" ++ user.name ++ "&userId=" ++ user.id
                , body = Http.emptyBody
                , expect = Http.expectJson event (roomDecoder (Room user))
                }


castVote room vote event =
    Http.post
        { url = urlAddress ("/vote?id=" ++ room.id ++ "&userId=" ++ room.user.id ++ "&vote=" ++ String.fromInt vote)
        , body = Http.emptyBody
        , expect = Http.expectJson event (roomDecoder (Room room.user))
        }


reveal room event =
    Http.post
        { url = urlAddress "/reveal?id=" ++ room.id
        , body = Http.emptyBody
        , expect = Http.expectJson event (roomDecoder (Room room.user))
        }


leave : String -> User -> (Result Error Room -> msg) -> Cmd msg
leave roomId user event =
    Http.post
        { url = urlAddress "/leave?id=" ++ roomId ++ "&userId=" ++ user.id
        , body = Http.emptyBody
        , expect = Http.expectJson event (roomDecoder (Room user))
        }


reset room event =
    Http.post
        { url = urlAddress "/reset?id=" ++ room.id
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
