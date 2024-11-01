module ValueBar exposing (..)

import Html exposing (Html, text)
import Html.Attributes
import Html.Events


type alias Model =
    { values : List Int
    }


type Msg
    = ClickValue Int


init =
    Model [ 1, 2, 3, 5, 8, 13, 21 ]


view model =
    Html.div []
        (List.map
            valueButton
            model.values
        )


valueButton : Int -> Html Msg
valueButton i =
    Html.button [ Html.Attributes.type_ "button", Html.Events.onClick (ClickValue i) ] [ text (String.fromInt i) ]
