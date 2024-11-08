port module Pokertool exposing (..)

import Browser exposing (UrlRequest)
import Html exposing (Html, text)
import Html.Events exposing (onClick)
import Http
import Room exposing (Room)
import Url exposing (Url)
import User exposing (User)
import ValueBar


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { roomId : Maybe String
    , currentUser : User
    , values : ValueBar.Model
    , votes : List Vote
    }


type alias Vote =
    { user : User
    , value : Int
    }


emptyModel : Maybe String -> Model
emptyModel roomId =
    Model roomId (User "enrico") ValueBar.init []


type Msg
    = CastVote ValueBar.Msg
    | Request String
    | CreateRoom
    | GotRoom (Result Http.Error Room)



-- PORTS


port openWebsocket : String -> Cmd msg


port roomUpdate : (String -> msg) -> Sub msg


init : Maybe String -> ( Model, Cmd Msg )
init roomId =
    ( emptyModel roomId, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


onUrlRequest : UrlRequest -> Msg
onUrlRequest request =
    Request (Debug.toString request)


onUrlChange : Url -> Msg
onUrlChange url =
    Request (Debug.toString url)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        CreateRoom ->
            ( model, createRoom )

        CastVote value ->
            case value of
                ValueBar.ClickValue vote ->
                    ( castVote vote model, Cmd.none )

        GotRoom result ->
            case result of
                Ok room ->
                    ( { model | roomId = Just room.id }, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        Request string ->
            ( model, Cmd.none )


createRoom : Cmd Msg
createRoom =
    Room.create GotRoom


castVote : Int -> Model -> Model
castVote value model =
    model


view : Model -> Html Msg
view model =
    case model.roomId of
        Just id ->
            Html.div []
                [ text ("hello, " ++ model.currentUser.name ++ id)
                , ValueBar.view model.values |> Html.map CastVote
                ]

        Nothing ->
            Html.div []
                [ text ("hello, " ++ model.currentUser.name ++ ", Create a new room: ")
                , Html.button [ onClick CreateRoom ] [ text "Create" ]
                ]
