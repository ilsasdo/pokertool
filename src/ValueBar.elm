module ValueBar exposing (..)

import Html exposing (Html, text)
import Html.Attributes
import Html.Events
import String exposing (toInt)


type Msg
    = ClickValue Int


view : List Int -> Html Msg
view values =
    Html.div []
        (List.map
            valueButton
            values
        )


valueButton : Int -> Html Msg
valueButton i =
    Html.button [ Html.Attributes.type_ "button", Html.Events.onClick (ClickValue i) ] [ text (String.fromInt i) ]
