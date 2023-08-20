module Pokertool exposing (..)

import Browser
import Html exposing (Html, button, div, h1, input, p, text)
import Html.Attributes exposing (class, href, placeholder, target, type_, value)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode exposing (field, int, list, string)
import Json.Encode as Encode


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


type alias Model =
    { currentUser : User
    , cardnameInput : String
    , room : Room
    }


type alias Card =
    { id : String
    , name : String
    }


type alias Estimation =
    { id : String, person : Person, vote : Int }


type alias Person =
    String


type alias Room =
    { id : String
    , name : String
    , partecipants : List Person
    , cards : List Card
    , estimations : List Estimation
    }


type User
    = LoggedIn String
    | Anonymous String


type Msg
    = CreateRoom
    | SetUsername
    | AddNewCard
    | RoomRetrieved (Result Http.Error Room)
    | RoomCreated (Result Http.Error Room)
    | InsertUsername String
    | InsertRoomName String
    | InsertCardName String


init : String -> ( Model, Cmd Msg )
init roomId =
    if roomId == "" then
        ( Model (Anonymous "") "" emptyRoom, Cmd.none )

    else
        ( Model (Anonymous "") "" emptyRoom
        , Http.get
            { url = "https://wa49q02ic4.execute-api.eu-north-1.amazonaws.com/rooms/" ++ roomId
            , expect = Http.expectJson RoomRetrieved roomDecoder
            }
        )


emptyRoom =
    Room "" "" [] [] []


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        InsertCardName cardname ->
            ( { model | cardnameInput = cardname }, Cmd.none )

        InsertUsername username ->
            ( { model | currentUser = Anonymous username }, Cmd.none )

        InsertRoomName roomname ->
            let
                room =
                    model.room
            in
            ( { model | room = { room | name = roomname } }, Cmd.none )

        RoomRetrieved result ->
            ( roomRetrieved model result, Cmd.none )

        RoomCreated result ->
            ( roomCreated model result, Cmd.none )

        CreateRoom ->
            ( model, cmdCreateRoom model.room.name model.currentUser )

        SetUsername ->
            ( model, cmdSetUsername model.room.id model.currentUser )

        AddNewCard ->
            ( model, cmdAddNewCard model.room.id model.cardnameInput )


cmdAddNewCard roomId cardnameInput =
    Http.post
        { url = "https://wa49q02ic4.execute-api.eu-north-1.amazonaws.com/rooms/" ++ roomId ++ "/addCard"
        , body = Http.jsonBody (nameEncoder cardnameInput)
        , expect = Http.expectJson RoomRetrieved roomDecoder
        }


cmdSetUsername roomId currentUser =
    case currentUser of
        Anonymous username ->
            Http.post
                { url = "https://wa49q02ic4.execute-api.eu-north-1.amazonaws.com/rooms/" ++ roomId ++ "/addPartecipant"
                , body = Http.jsonBody (nameEncoder username)
                , expect = Http.expectJson RoomCreated roomDecoder
                }

        LoggedIn username ->
            Cmd.none


cmdCreateRoom roomname currentUser =
    case currentUser of
        Anonymous username ->
            Http.request
                { method = "PUT"
                , headers = []
                , url = "https://wa49q02ic4.execute-api.eu-north-1.amazonaws.com/rooms"
                , body = Http.jsonBody (createRoomEncoder roomname username)
                , expect = Http.expectJson RoomCreated roomDecoder
                , timeout = Just 5000
                , tracker = Nothing
                }

        LoggedIn username ->
            Cmd.none


nameEncoder username =
    Encode.object
        [ ( "name", Encode.string username )
        ]


createRoomEncoder roomname username =
    Encode.object
        [ ( "name", Encode.string roomname )
        , ( "user", Encode.string username )
        ]


roomDecoder =
    Json.Decode.map5 Room
        (field "id" string)
        (field "name" string)
        (field "partecipants" (list partecipantDecoder))
        (field "cards" (list cardDecoder))
        (field "estimations" (list estimationDecoder))


partecipantDecoder =
    Json.Decode.string


cardDecoder =
    Json.Decode.map2 Card
        (field "id" string)
        (field "name" string)


estimationDecoder =
    Json.Decode.map3 Estimation
        (field "id" string)
        (field "person" partecipantDecoder)
        (field "vote" int)


roomRetrieved model result =
    case result of
        Result.Ok room ->
            { model | room = room }

        Result.Err error ->
            model


roomCreated model result =
    case result of
        Result.Ok room ->
            { model | room = room, currentUser = toLoggedInUser model.currentUser }

        Result.Err error ->
            model


toLoggedInUser user =
    case user of
        LoggedIn u ->
            user

        Anonymous u ->
            LoggedIn u


view : Model -> Html Msg
view model =
    div [ class "container mx-auto" ]
        (viewPageTitle "Poker Tool"
            :: viewRoom model
        )


viewRoom model =
    case model.room.id of
        "" ->
            [ viewAskForRoomName model.room.name
            , viewCurrentUser model
            , viewCreateRoom
            ]

        _ ->
            [ viewCurrentUser model
            , viewSetUsername
            , viewRoomData model.room
            , viewAddNewCard model.cardnameInput
            ]


viewAddNewCard cardname =
    div []
        [ input [ type_ "text", class "input", placeholder "Card name", onInput InsertCardName, value cardname ] []
        , button [ class "btn", onClick AddNewCard ] [ text "Add Card" ]
        ]


viewCreateRoom =
    div [] [ button [ class "btn", onClick CreateRoom ] [ text "Create Room" ] ]


viewSetUsername =
    div [] [ button [ class "btn", onClick SetUsername ] [ text "Set username" ] ]


viewRoomData room =
    div []
        [ p [] [ text ("Name: " ++ room.name) ]
        , p [] [ text ("Partecipants: " ++ Debug.toString room.partecipants) ]
        , p [] [ text ("Cards: " ++ Debug.toString room.cards) ]
        , p [] [ text "Share link: ", viewRoomLink room.id ]
        ]


viewRoomLink id =
    Html.a [ href ("http://localhost:8000?roomId=" ++ id), target "blank" ] [ text "Share the link" ]


viewCurrentUser model =
    case model.currentUser of
        Anonymous tempUsername ->
            viewAskForUser tempUsername

        LoggedIn username ->
            viewLoggedInUser username


viewAskForRoomName roomname =
    div []
        [ text "Room name:"
        , input
            [ type_ "text"
            , class "input"
            , placeholder "Insert room name"
            , onInput InsertRoomName
            , value roomname
            ]
            []
        ]


viewAskForUser tempUsername =
    div []
        [ text "Username:"
        , input
            [ type_ "text"
            , class "input"
            , placeholder "Insert your name"
            , onInput InsertUsername
            , value tempUsername
            ]
            []
        ]


viewLoggedInUser username =
    div []
        [ p [] [ text ("Logged user:" ++ username) ]
        ]


viewPageTitle title =
    h1 [ class "text-center font-bold" ] [ text title ]
