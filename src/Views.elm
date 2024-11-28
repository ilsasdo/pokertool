module Views exposing (..)

import Html exposing (Html, div, h1, p, text)
import Html.Attributes exposing (class, disabled, for, href, id, placeholder, type_, value)
import Html.Events exposing (onClick, onInput)


page : Html msg -> Html msg -> Html msg
page headerEl bodyEl =
    Html.div
        [ class "container" ]
        [ header headerEl, body bodyEl, footer ]


header : Html msg -> Html msg
header el =
    Html.nav
        [ class "navbar bg-body-tertiary" ]
        [ div
            [ class "navbar-brand text-center" ]
            [ h1 [] [ text "poker estimation tool" ] ]
        , el
        ]


body el =
    Html.div [ class "row justify-content-center mt-5" ] [ el ]


footer =
    Html.div [ class "row" ] []


insertUserName : (String -> msg) -> String -> Html msg
insertUserName event model =
    Html.div [ class "mt-3" ]
        [ Html.label [ class "form-label", for "username" ] [ text "Insert your name:" ]
        , textInput { placeholder = "" } event model
        ]


textInput : { placeholder : String } -> (String -> msg) -> String -> Html msg
textInput options event model =
    Html.input [ class "form-control", id "username", type_ "text", placeholder options.placeholder, onInput event, value model ] []


button : msg -> String -> Bool -> Html msg
button event label enabled =
    Html.button [ class "btn btn-primary w-100", type_ "button", onClick event, disabled (not enabled) ] [ text label ]


linkButton : String -> String -> Bool -> Html msg
linkButton label url enabled =
    Html.a [ href url, disabled (not enabled) ] [ text label ]


alwaysPreventDefault : msg -> ( msg, Bool )
alwaysPreventDefault msg =
    ( msg, True )


hint : String -> Html msg
hint t =
    Html.div [ class "form-text mt-0 mb-4 text-end" ] [ text t ]


centered children =
    Html.div [ class "col-md-4" ] children


centeredLarge children =
    Html.div [ class "col-md-6" ] children
