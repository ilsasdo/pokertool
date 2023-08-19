module Pokertool exposing (..)

import Browser
import Dict exposing (Dict)
import Html exposing (Html, button, div, h1, h3, input, label, p, text)
import Html.Attributes exposing (class, for, href, id, placeholder, target, type_, value)
import Html.Events exposing (onClick, onInput)


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
    , room : Room
    , inputUsername : String
    , inputRoomId : String
    , inputRoomName : String
    , inputCardname : String
    }


emptyModel : Model
emptyModel =
    Model Anonymous emptyRoom "" "" "" ""


type alias Room =
    { id : String
    , name : String
    , cardToVote : Maybe Card
    , cards : List Card
    }


emptyRoom =
    Room "" "" Nothing []


isEmptyRoom room =
    room.id == "" && room.name == ""


type alias Card =
    { id : String
    , name : String
    , votes : Dict String Int
    }


type Msg
    = SetUsername
    | LoadRoom
    | CreateRoom
    | AddCard
    | SelectCard Card
    | CastVote Card Int
    | InputUsername String
    | InputRoomId String
    | InputTaskName String
    | InputRoomName String


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
            ( { model | room = Room model.inputRoomId "fake name" Nothing [] }, Cmd.none )

        CreateRoom ->
            ( { model | room = Room "f01kaxk3" model.inputRoomName Nothing [] }, Cmd.none )

        AddCard ->
            ( { model | room = addCard model.inputCardname model.room, inputCardname = "" }, Cmd.none )

        SelectCard card ->
            ( { model | room = selectCard card model.room }, Cmd.none )

        CastVote card value ->
            ( { model | room = castVote card model.currentUser value model.room }, Cmd.none )


addCard : String -> Room -> Room
addCard cardname room =
    { room | cards = room.cards ++ [ Card "id" cardname Dict.empty ] }


selectCard : Card -> Room -> Room
selectCard card room =
    { room | cardToVote = Just card }


castVote : Card -> User -> Int -> Room -> Room
castVote card user vote room =
    let
        votedCard =
            { card | votes = Dict.insert (getUsername user) vote card.votes }
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


view : Model -> Html Msg
view model =
    div []
        ([ h1 [] [ text "Pokertool" ]
         , viewCurrentUser model.currentUser
         ]
            ++ viewRoom model.room
            ++ (viewAskForUserName model :: viewAskForRoom model)
            ++ viewAddNewCard model
            ++ viewVoteCard model.room.cardToVote
        )


viewCurrentUser user =
    p [] [ text (getUsername user) ]


viewRoom : Room -> List (Html Msg)
viewRoom room =
    if isEmptyRoom room then
        [ p [] [ text "Empty Room" ] ]

    else
        [ p [] [ text ("id: " ++ room.id) ]
        , p [] [ text ("name: " ++ room.name) ]
        , p []
            [ Html.ul [] (List.map viewCard room.cards)
            ]
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
    votes
        |> Dict.toList
        |> List.map Tuple.second
        |> List.foldl (+) 0
        |> toFloat
        |> (/) (Dict.size votes |> toFloat)


viewVoteCard : Maybe Card -> List (Html Msg)
viewVoteCard maybeCard =
    case maybeCard of
        Nothing ->
            []

        Just card ->
            [ div []
                [ h3 [] [ text ("Vote for card: " ++ card.name) ]
                , p [] (List.map (viewVoteButton card) [ 1, 2, 3, 5, 8, 13, 21 ])
                ]
            ]


viewVoteButton card value =
    button [ onClick (CastVote card value) ] [ text (String.fromInt value) ]


viewAddNewCard : Model -> List (Html Msg)
viewAddNewCard model =
    if isAnonymous model.currentUser || isEmptyRoom model.room then
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
    if isAnonymous model.currentUser || not (isEmptyRoom model.room) then
        []

    else
        [ div []
            [ label [ for "roomId" ] [ text "Join existing Room:" ]
            , input [ id "roomId", type_ "text", onInput InputRoomId, placeholder "Room Id" ] []
            , button [ onClick LoadRoom ] [ text "Join" ]
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
