port module Pokertool exposing (..)

import Browser
import Html exposing (Html, text)
import User exposing (User)
import ValueBar


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


type alias Model =
    { currentUser : User
    , values : ValueBar.Model
    , votes : List Vote
    }


type alias Vote =
    { user : User
    , value : Int
    }


emptyModel : Model
emptyModel =
    Model (User "enrico") ValueBar.init []


type Msg
    = CastVote ValueBar.Msg



-- PORTS


port openWebsocket : String -> Cmd msg


port roomUpdate : (String -> msg) -> Sub msg


init : () -> ( Model, Cmd Msg )
init _ =
    ( emptyModel, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        CastVote value ->
            case value of
                ValueBar.ClickValue vote ->
                    ( castVote vote model, Cmd.none )

        _ ->
            ( model, Cmd.none )


castVote : Int -> Model -> Model
castVote value model =
    model


view : Model -> Html Msg
view model =
    Html.div []
        [ text ("hello, " ++ model.currentUser.name)
        , ValueBar.view model.values |> Html.map CastVote
        ]
