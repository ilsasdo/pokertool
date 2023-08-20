module Pokertool exposing (..)

import Browser
import Dict exposing (Dict)
import Html exposing (Html, button, div, h1, h3, input, label, p, text)
import Html.Attributes exposing (class, for, href, id, placeholder, style, target, type_, value)
import Html.Events exposing (onClick, onInput)
import Http exposing (Error)
import Room exposing (Card, Room, addCard, castVote, isEmptyRoom, selectCard)


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


type User
    = Anonymous
    | LoggedIn String


isAnonymous user =
    user == Anonymous


getUsername user =
    case user of
        Anonymous ->
            "Anonymous"

        LoggedIn username ->
            username


type alias Model =
    { currentUser : User
    , room : Maybe Room
    , loadingMessage : Maybe String
    , error : Maybe Error
    , inputUsername : String
    , inputRoomId : String
    , inputRoomName : String
    , inputCardname : String
    }


emptyModel : Model
emptyModel =
    Model Anonymous Nothing Nothing Nothing "" "" "" ""


type Msg
    = SetUsername
    | CreateRoom
    | LoadRoom
    | JoinRoom
    | AddCard
    | SelectCard Card
    | CastVote Card Int
    | InputUsername String
    | InputRoomId String
    | InputTaskName String
    | InputRoomName String
    | HttpRoomLoaded (Result Http.Error Room)


init : () -> ( Model, Cmd Msg )
init _ =
    ( emptyModel, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        InputUsername value ->
            ( { model | inputUsername = value }, Cmd.none )

        InputTaskName value ->
            ( { model | inputCardname = value }, Cmd.none )

        InputRoomId value ->
            ( { model | inputRoomId = value }, Cmd.none )

        InputRoomName value ->
            ( { model | inputRoomName = value }, Cmd.none )

        SetUsername ->
            ( { model | currentUser = LoggedIn model.inputUsername }, Cmd.none )

        LoadRoom ->
            case model.room of
                Nothing ->
                    ( model, Cmd.none )

                Just room ->
                    ( { model | loadingMessage = Just "Loading Room..." }
                    , Room.loadRoom room.id HttpRoomLoaded
                    )

        JoinRoom ->
            ( { model | loadingMessage = Just "Joining room..." }
            , Room.joinRoom model.inputRoomId (getUsername model.currentUser) HttpRoomLoaded
            )

        CreateRoom ->
            ( { model | loadingMessage = Just "Room creation in progress..." }
            , Room.createRoom model.inputRoomName (getUsername model.currentUser) HttpRoomLoaded
            )

        HttpRoomLoaded result ->
            case result of
                Ok room ->
                    ( { model | room = Just room, loadingMessage = Nothing, error = Nothing }, Cmd.none )

                Err message ->
                    ( { model | error = Just message, loadingMessage = Nothing }, Cmd.none )

        AddCard ->
            ( { model
                | room =
                    model.room |> Maybe.map (addCard model.inputCardname)
                , inputCardname = ""
              }
            , Cmd.none
            )

        SelectCard card ->
            ( { model | room = model.room |> Maybe.map (selectCard card) }, Cmd.none )

        CastVote card value ->
            ( { model | room = model.room |> Maybe.map (castVote card (getUsername model.currentUser) value) }, Cmd.none )


view : Model -> Html Msg
view model =
    div []
        ([ h1 [] [ text "Pokertool" ]
         , viewLoadingMessage model.loadingMessage
         , viewErrorMessage model.error
         , viewCurrentUser model.currentUser
         ]
            ++ viewRoom model.room
            ++ (viewAskForUserName model :: viewAskForRoom model)
            ++ viewAddNewCard model
            ++ viewVoteCard model.room
        )


viewErrorMessage error =
    if error /= Nothing then
        p [ style "color" "red" ] [ text (Debug.toString error) ]

    else
        text ""


viewLoadingMessage message =
    case message of
        Nothing ->
            text ""

        Just m ->
            p [] [ text m ]


viewCurrentUser user =
    p [] [ text (getUsername user) ]


viewRoom : Maybe Room -> List (Html Msg)
viewRoom room =
    case room of
        Nothing ->
            [ p [] [ text "Empty Room" ] ]

        Just r ->
            [ p [] [ text ("id: " ++ r.id), button [ onClick LoadRoom ] [ text "reload" ] ]
            , p [] [ text ("name: " ++ r.name) ]
            , p []
                [ text "Partecipants:"
                , Html.ul [] (List.map viewPartecipant r.partecipants)
                ]
            , p []
                [ text "Cards:"
                , Html.ul [] (List.map viewCard r.cards)
                ]
            ]


viewPartecipant partecipant =
    Html.li []
        [ p [] [ text partecipant ]
        ]


viewCard : Card -> Html Msg
viewCard card =
    Html.li []
        [ p []
            [ text (card.name ++ ", ")
            , text ("votes: " ++ (card.votes |> Dict.toList |> List.map (\( u, v ) -> u ++ ": " ++ String.fromInt v) |> String.join ", "))
            , text (", value: " ++ (computeCardValue card.votes |> String.fromFloat))
            , button [ onClick (SelectCard card) ] [ text "Select" ]
            ]
        ]


computeCardValue : Dict String Int -> Float
computeCardValue votes =
    (votes
        |> Dict.toList
        |> List.map Tuple.second
        |> List.foldl (+) 0
        |> toFloat
    )
        / (Dict.size votes |> toFloat)


viewVoteCard : Maybe Room -> List (Html Msg)
viewVoteCard maybeRoom =
    maybeRoom
        |> Maybe.andThen .cardToVote
        |> Maybe.map
            (\card ->
                [ div []
                    [ h3 [] [ text ("Vote for card: " ++ card.name) ]
                    , p [] (List.map (viewVoteButton card) [ 1, 2, 3, 5, 8, 13, 21 ])
                    ]
                ]
            )
        |> Maybe.withDefault []


viewVoteButton card value =
    button [ onClick (CastVote card value) ] [ text (String.fromInt value) ]


viewAddNewCard : Model -> List (Html Msg)
viewAddNewCard model =
    case model.room of
        Nothing ->
            []

        Just room ->
            if isAnonymous model.currentUser then
                []

            else
                [ div []
                    [ label [ for "cardname" ] [ text "Add new Card:" ]
                    , input [ id "cardname", type_ "text", onInput InputTaskName, placeholder "name", value model.inputCardname ] []
                    , button [ onClick AddCard ] [ text "Add" ]
                    ]
                ]


viewAskForRoom : Model -> List (Html Msg)
viewAskForRoom model =
    case model.room of
        Just room ->
            []

        Nothing ->
            if isAnonymous model.currentUser then
                []

            else
                [ div []
                    [ label [ for "roomId" ] [ text "Join existing Room:" ]
                    , input [ id "roomId", type_ "text", onInput InputRoomId, placeholder "Room Id" ] []
                    , button [ onClick JoinRoom ] [ text "Join" ]
                    ]
                , div []
                    [ label [ for "roomName" ] [ text "Create a new Room:" ]
                    , input [ id "roomName", type_ "text", onInput InputRoomName, placeholder "Name" ] []
                    , button [ onClick CreateRoom ] [ text "Create" ]
                    ]
                ]


viewAskForUserName : Model -> Html Msg
viewAskForUserName model =
    if isAnonymous model.currentUser then
        div []
            [ label [ for "username" ] [ text "Insert username:" ]
            , input [ id "username", type_ "text", onInput InputUsername ] []
            , button [ onClick SetUsername ] [ text "Set" ]
            ]

    else
        text ""
