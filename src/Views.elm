module Views exposing (..)

import Html exposing (Html, div, h1, p, text)
import Html.Attributes exposing (class, disabled, for, id, type_, value)
import Html.Events exposing (onClick, onInput)


page el =
    Html.div
        [ class "container" ]
        [ header, body el, footer ]


header =
    Html.nav
        [ class "navbar navbar-expand-lg bg-body-tertiary bg-body-tertiary rounded" ]
        [ div
            [ class "navbar-brand text-center" ]
            [ h1 [] [ text "poker estimation tool" ] ]
        ]


body el =
    Html.div [ class "row justify-content-center mt-5" ] [ el ]


footer =
    Html.div [ class "row" ] []


insertUserName : (String -> msg) -> String -> Html msg
insertUserName event model =
    Html.div [ class "my-3" ]
        [ Html.label [ class "form-label", for "username" ] [ text "Insert your name:" ]
        , textInput event model
        ]


textInput event model =
    Html.input [ class "form-control", id "username", type_ "text", onInput event, value model ] []


button : msg -> String -> Bool -> Html msg
button event label enabled =
    Html.button [ class "btn btn-primary", type_ "button", onClick event, disabled (not enabled) ] [ text label ]


hint : String -> Html msg
hint t =
    Html.div [ class "form-text" ] [ text t ]
