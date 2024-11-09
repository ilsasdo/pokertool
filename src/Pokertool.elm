port module Pokertool exposing (..)

import Browser exposing (UrlRequest)
import Html exposing (Html, text)
import Html.Attributes exposing (type_, value)
import Html.Events exposing (onClick, onInput)
import Http
import Room exposing (Room)
import Url exposing (Url)


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias LoadingRoom =
    { inputUser : String, roomId : Maybe String, user : Maybe User }


type alias LoadedRoom =
    { room : Room
    , user : User
    , values : List Int
    }


type Model
    = LoadingRoomState LoadingRoom
    | FullLoadedRoomState LoadedRoom


type alias Member =
    { user : User
    , value : Int
    }


type alias User =
    { name : String }


emptyModel : Maybe String -> Model
emptyModel roomId =
    LoadingRoomState { inputUser = "", roomId = roomId, user = Nothing }


type Msg
    = CastVote Int
    | Request String
    | CreateRoom
    | GotRoom (Result Http.Error Room)
    | InputUser String
    | JoinRoom
    | Reveal
    | Reset



-- PORTS


port openWebsocket : String -> Cmd msg


port roomUpdate : (String -> msg) -> Sub msg


init : Maybe String -> ( Model, Cmd Msg )
init roomId =
    ( emptyModel roomId, Cmd.none )


initFullRoom room user =
    LoadedRoom room (User user) [ 1, 2, 3, 5, 8, 13, 21 ]


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
    case model of
        LoadingRoomState loadingRoom ->
            case msg of
                CreateRoom ->
                    case loadingRoom.user of
                        Just user ->
                            ( model, Room.create user.name GotRoom )

                        Nothing ->
                            ( model, Cmd.none )

                GotRoom result ->
                    case result of
                        Ok room ->
                            ( FullLoadedRoomState (initFullRoom room room.user), Cmd.none )

                        Err _ ->
                            ( model, Cmd.none )

                JoinRoom ->
                    ( model, Room.join loadingRoom.roomId loadingRoom.inputUser GotRoom )

                InputUser user ->
                    ( LoadingRoomState { loadingRoom | inputUser = user }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        FullLoadedRoomState loadedRoom ->
            case msg of
                CastVote vote ->
                    ( model, Room.castVote loadedRoom.room.id loadedRoom.room.user vote GotRoom )

                Reveal ->
                    ( model, Room.reveal loadedRoom.room.id loadedRoom.room.user GotRoom )

                Reset ->
                    ( model, Room.reset loadedRoom.room.id loadedRoom.room.user GotRoom )

                GotRoom result ->
                    case result of
                        Ok room ->
                            ( FullLoadedRoomState (initFullRoom room room.user), Cmd.none )

                        Err _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )


toMember : ( String, Int ) -> Member
toMember ( name, vote ) =
    Member (User name) vote


castVote : Int -> Model -> Model
castVote value model =
    model


view : Model -> Html Msg
view model =
    case model of
        LoadingRoomState loadingRoom ->
            askUser loadingRoom

        FullLoadedRoomState loadedRoom ->
            viewRoom loadedRoom


askUser : LoadingRoom -> Html Msg
askUser model =
    case model.user of
        Nothing ->
            Html.div []
                [ text "Please insert your name: "
                , Html.input [ type_ "text", onInput InputUser, value model.inputUser ] []
                , Html.button [ type_ "button", onClick JoinRoom ] [ text "Join" ]
                ]

        Just user ->
            Html.div []
                [ text ("hello, " ++ user.name ++ ", Create a new room: ")
                , Html.button [ onClick CreateRoom ] [ text "Create" ]
                ]


viewRoom : LoadedRoom -> Html Msg
viewRoom model =
    Html.div []
        [ Html.p [] [ text ("hello, " ++ model.user.name) ]
        , Html.p [] [ text ("room id: " ++ model.room.id) ]
        , viewValueBar model.values
        , viewMembers model.room
        , viewRevealButton model
        ]


viewMembers room =
    Html.ul [] (List.map (viewMember room.revealed) (room.members |> List.sortBy (\t -> t.username)))


viewMember revealed member =
    Html.li [] [ text (member.username ++ ": "), viewVote revealed member.vote ]


viewVote revealed vote =
    if revealed then
        text (String.fromInt vote)

    else
        text "hidden"


viewRevealButton : LoadedRoom -> Html Msg
viewRevealButton model =
    if model.room.revealed then
        Html.p [] [ Html.button [ onClick Reset ] [ text "Reset" ] ]

    else
        Html.p [] [ Html.button [ onClick Reveal ] [ text "Reveal" ] ]


viewValueBar : List Int -> Html Msg
viewValueBar values =
    Html.div []
        (List.map
            valueButton
            values
        )


valueButton : Int -> Html Msg
valueButton i =
    Html.button [ Html.Attributes.type_ "button", Html.Events.onClick (CastVote i) ] [ text (String.fromInt i) ]
