module Room exposing (..)

import Dict exposing (Dict)
import Http
import Json.Decode as Decode exposing (Decoder, field, int, list, string)
import Json.Encode as Encode


type alias Room =
    { id : String
    , name : String
    , rootUser : Username
    , partecipants : List Username
    , cardToVote : Maybe String
    , cards : List Card
    }


type alias Card =
    { id : String
    , name : String
    , votes : Dict Username Int
    }


type alias Username =
    String


urlAddress part =
    "https://prcmtg3w83.execute-api.eu-west-1.amazonaws.com" ++ part


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


addCard roomId cardname event =
    Http.post
        { url = urlAddress ("/rooms/" ++ roomId ++ "/addCard")
        , body = Http.jsonBody (addCardEncoder cardname)
        , expect = Http.expectJson event (roomDecoder Room)
        }


selectCard : Card -> (Result Http.Error Room -> a) -> Room -> Cmd a
selectCard card event room =
    Http.post
        { url = urlAddress ("/rooms/" ++ room.id ++ "/selectCard")
        , body = Http.jsonBody (selectCardEncoder card.id)
        , expect = Http.expectJson event (roomDecoder Room)
        }


castVote : String -> Card -> Int -> (Result Http.Error Room -> a) -> Room -> Cmd a
castVote username card vote event room =
    Http.post
        { url = urlAddress ("/rooms/" ++ room.id ++ "/castVote")
        , body = Http.jsonBody (castVoteEncoder (getCardIndex card.id room.cards) username vote)
        , expect = Http.expectJson event (roomDecoder Room)
        }


selectCardEncoder cardId =
    Encode.object
        [ ( "cardId", Encode.string cardId )
        ]


castVoteEncoder cardname username vote =
    Encode.object
        [ ( "cardIndex", Encode.int cardname )
        , ( "username", Encode.string username )
        , ( "vote", Encode.int vote )
        ]


addCardEncoder cardname =
    Encode.object
        [ ( "name", Encode.string cardname )
        ]


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
        (Decode.maybe (field "selectedCard" string))
        (field "cards" (list cardDecoder))


cardDecoder =
    Decode.map3 Card
        (field "id" string)
        (field "name" string)
        (field "votes" (Decode.dict int))


getCardToVote : Room -> Maybe Card
getCardToVote room =
    room.cards
        |> List.filter (.id >> (==) (room.cardToVote |> Maybe.withDefault ""))
        |> List.head


getCardIndex : String -> List Card -> Int
getCardIndex cardId cards =
    cards
        |> List.indexedMap Tuple.pair
        |> List.filter (Tuple.second >> .id >> (==) cardId)
        |> List.map Tuple.first
        |> List.head
        |> Maybe.withDefault 0
