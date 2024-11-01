module Views exposing (..)

import Html exposing (Attribute, Html, text)
import Html.Attributes exposing (class)


title t =
    Html.h1 [ class "text-6xl" ] [ Html.text t ]


box : List (Attribute msg) -> List (Html msg) -> Html msg
box attributes content =
    Html.div ([ class "p-3 border bg-slate-50 inline-block shadow-old" ] ++ attributes) content


container content =
    Html.div [ class "p-3 container mx-auto" ] content


row content =
    Html.div [ class "grid grid-rows-1" ] content


textInput =
    Html.input [] []


button attrs label =
    Html.button ([ class "bg-slate-100" ] ++ attrs) [ Html.text label ]


text attrs t =
    Html.span attrs [ Html.text t ]
