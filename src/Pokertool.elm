port module Pokertool exposing (..)

import Browser exposing (UrlRequest)
import Html exposing (Html, text)
import Html.Attributes exposing (type_, value)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode exposing (Decoder, field, string)
import Json.Encode
import Random
import Room exposing (Room, User, UserVote)
import UUID exposing (UUID)
import Url exposing (Url)


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias LoadingRoom =
    { inputUser : String, roomId : Maybe String, user : Maybe User, userUuid : String }


type alias LoadedRoom =
    { room : Room
    , user : User
    , values : List Int
    }


type Model
    = LoadingRoomState LoadingRoom
    | FullLoadedRoomState LoadedRoom


emptyModel : Maybe String -> Model
emptyModel roomId =
    LoadingRoomState { inputUser = "", roomId = roomId, user = Nothing, userUuid = "" }


type Msg
    = CastVote Int
    | Request String
    | CreateRoom
    | GotRoom (Result Http.Error Room)
    | InputUser String
    | JoinRoom
    | Reveal
    | Reset
    | UuidGenerated UUID
    | LoggedInUser (Maybe User)



-- PORTS


port storeUser : User -> Cmd msg


port loadUser : (String -> msg) -> Sub msg


init : Maybe String -> ( Model, Cmd Msg )
init roomId =
    ( emptyModel roomId, generateUuid )


initFullRoom room user =
    LoadedRoom room user [ 1, 2, 3, 5, 8, 13, 21 ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    loadUser userDecoder


userDecoder : String -> Msg
userDecoder value =
    case
        Json.Decode.decodeString
            (Json.Decode.map2 User
                (field "id" string)
                (field "name" string)
            )
            (Debug.log "userDecode" value)
    of
        Ok user ->
            LoggedInUser (Just user)

        Err _ ->
            LoggedInUser Nothing


onUrlRequest : UrlRequest -> Msg
onUrlRequest request =
    Request (Debug.toString request)


onUrlChange : Url -> Msg
onUrlChange url =
    Request (Debug.toString url)


generateUuid : Cmd Msg
generateUuid =
    Random.generate UuidGenerated UUID.generator


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case model of
        LoadingRoomState loadingRoom ->
            case msg of
                LoggedInUser user ->
                    case Debug.log "LoggedIn" user of
                        Just u ->
                            ( LoadingRoomState { loadingRoom | userUuid = u.id, user = user }, Cmd.none )

                        Nothing ->
                            ( model, generateUuid )

                UuidGenerated uuid ->
                    ( LoadingRoomState { loadingRoom | userUuid = UUID.toString uuid }, Cmd.none )

                CreateRoom ->
                    case loadingRoom.user of
                        Just user ->
                            ( model, Room.create user GotRoom )

                        Nothing ->
                            ( model, Cmd.none )

                GotRoom result ->
                    case result of
                        Ok room ->
                            ( FullLoadedRoomState (initFullRoom room room.user), storeUser room.user )

                        Err _ ->
                            ( model, Cmd.none )

                JoinRoom ->
                    ( model, Room.join loadingRoom.roomId (User loadingRoom.userUuid loadingRoom.inputUser) GotRoom )

                InputUser user ->
                    ( LoadingRoomState { loadingRoom | inputUser = user }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        FullLoadedRoomState loadedRoom ->
            case msg of
                CastVote vote ->
                    ( model, Room.castVote loadedRoom.room vote GotRoom )

                Reveal ->
                    ( model, Room.reveal loadedRoom.room GotRoom )

                Reset ->
                    ( model, Room.reset loadedRoom.room GotRoom )

                GotRoom result ->
                    case result of
                        Ok room ->
                            ( FullLoadedRoomState (initFullRoom room room.user), Cmd.none )

                        Err _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )


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
        , viewUserVotes model.room
        , viewRevealButton model
        ]


viewUserVotes : Room -> Html msg
viewUserVotes room =
    Html.ul [] (List.map (viewUserVote room.revealed) (room.members |> List.sortBy (\t -> t.user.name)))


viewUserVote : Bool -> UserVote -> Html msg
viewUserVote revealed userVote =
    Html.li [] [ text (userVote.user.name ++ ": "), viewVote revealed userVote.vote ]


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
