port module Pokertool exposing (..)

import Browser exposing (UrlRequest)
import Html exposing (Html, text)
import Html.Attributes exposing (class, value)
import Html.Events exposing (onClick)
import Http
import Json.Decode exposing (Decoder, field, string)
import Random
import Room exposing (Room, User, UserVote)
import Time exposing (Posix, posixToMillis)
import UUID exposing (UUID)
import Url exposing (Url)
import Views


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias LoadingRoom =
    { inputUser : String
    , roomId : Maybe String
    , user : Maybe User
    , userUuid : String
    , inputRoomId : String
    }


type alias LoadedRoom =
    { room : Room
    , user : User
    , values : List Int
    , lastPing : Int
    }


type Model
    = LoadingRoomState LoadingRoom
    | FullLoadedRoomState LoadedRoom


emptyModel : Maybe String -> Model
emptyModel roomId =
    LoadingRoomState { inputUser = "", roomId = roomId, user = Nothing, userUuid = "", inputRoomId = "" }


type Msg
    = CastVote Int
    | Request String
    | CreateRoom
    | GotRoom (Result Http.Error Room)
    | GotPing Posix (Result Http.Error Room)
    | InputUser String
    | InputRoomId String
    | Login
    | JoinRoom
    | Reveal
    | Reset
    | UuidGenerated UUID
    | LoggedInUser (Maybe User)
    | Logout
    | Ping Posix
    | LoggedOut (Result Http.Error Room)



-- PORTS


port storeUser : User -> Cmd msg


port loadUser : (String -> msg) -> Sub msg


port logout : () -> Cmd msg


pingTimeSeconds =
    5


init : Maybe String -> ( Model, Cmd Msg )
init roomId =
    ( emptyModel (Debug.log "init" roomId), generateUserUUID )


initFullRoom room user =
    LoadedRoom room user [ 1, 2, 3, 5, 8, 13, 21 ] 0


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch [ loadUser userDecoder, Time.every (pingTimeSeconds * 1000) Ping ]


userDecoder : String -> Msg
userDecoder value =
    case
        Json.Decode.decodeString
            (Json.Decode.map2 User
                (field "id" string)
                (field "name" string)
            )
            value
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


generateUserUUID : Cmd Msg
generateUserUUID =
    Random.generate UuidGenerated UUID.generator


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case model of
        LoadingRoomState loadingRoom ->
            case msg of
                LoggedInUser user ->
                    case user of
                        Just u ->
                            case loadingRoom.roomId of
                                Just roomId ->
                                    ( model, Room.join (Just roomId) u GotRoom )

                                Nothing ->
                                    ( LoadingRoomState { loadingRoom | userUuid = u.id, user = user }, Cmd.none )

                        Nothing ->
                            ( model, generateUserUUID )

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

                InputRoomId roomId ->
                    ( LoadingRoomState { loadingRoom | inputRoomId = roomId }, Cmd.none )

                Login ->
                    let
                        user =
                            User loadingRoom.userUuid loadingRoom.inputUser
                    in
                    ( LoadingRoomState { loadingRoom | user = Just user }, storeUser user )

                LoggedOut _ ->
                    ( emptyModel Nothing, logout () )

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

                GotPing posix result ->
                    case result of
                        Ok room ->
                            ( FullLoadedRoomState { loadedRoom | room = room, user = room.user, lastPing = posixToMillis posix // 1000 }, Cmd.none )

                        Err _ ->
                            ( model, Cmd.none )

                GotRoom result ->
                    case result of
                        Ok room ->
                            ( FullLoadedRoomState { loadedRoom | room = room, user = room.user }, Cmd.none )

                        Err _ ->
                            ( model, Cmd.none )

                LoggedOut _ ->
                    ( emptyModel Nothing, logout () )

                Logout ->
                    ( emptyModel Nothing, Room.leave loadedRoom.room LoggedOut )

                Ping posix ->
                    ( FullLoadedRoomState { loadedRoom | lastPing = posixToMillis posix // 1000 }, Room.ping loadedRoom.room.id loadedRoom.user GotRoom )

                _ ->
                    ( model, Cmd.none )


view : Model -> Html Msg
view model =
    case model of
        LoadingRoomState loadingRoom ->
            Views.page <| askUser loadingRoom

        FullLoadedRoomState loadedRoom ->
            Views.page <| viewRoom loadedRoom


askUser : LoadingRoom -> Html Msg
askUser model =
    case model.user of
        Nothing ->
            case model.roomId of
                Just roomId ->
                    Html.div [ class "col" ]
                        [ Views.insertUserName InputUser model.inputUser
                        , Views.button JoinRoom "Join" True
                        ]

                Nothing ->
                    Html.div [ class "col-md-6" ]
                        [ Views.insertUserName InputUser model.inputUser
                        , Views.hint "A valid user name must be at least 3 character long"
                        , Views.button Login "Login" (isValidUser model.inputUser)
                        ]

        Just user ->
            Html.div [ class "col-md-6 text-center" ]
                [ Html.p [] [ text ("Hello " ++ user.name ++ ",") ]
                , Html.p [] [ Views.button CreateRoom "Create a New room" True ]
                , Html.p [] [ text "or" ]
                , Views.textInput InputRoomId model.inputRoomId
                , Views.hint "Paste a valid Room Id"
                , Html.p [] [ Views.button CreateRoom "Join an Existing One" (isValidRoomId model.inputRoomId) ]
                ]


isValidUser name =
    name
        |> String.trim
        |> String.length
        |> (<=) 3


isValidRoomId name =
    name
        |> String.trim
        |> String.length
        |> (<=) 36


viewRoom : LoadedRoom -> Html Msg
viewRoom model =
    Html.div []
        [ Html.p [] [ text ("hello, " ++ model.user.name) ]
        , Html.p [] [ text ("room id: " ++ model.room.id) ]
        , Html.p [] [ text ("last ping: " ++ String.fromInt model.lastPing) ]
        , viewValueBar model.values
        , viewUserVotes model
        , viewRevealButton model
        , viewLogoutButton model
        ]


viewUserVotes : LoadedRoom -> Html msg
viewUserVotes model =
    Html.ul [] (List.map (viewUserVote model) (model.room.members |> List.sortBy (\t -> t.user.id) |> List.sortBy (\t -> t.user.name)))


viewUserVote : LoadedRoom -> UserVote -> Html msg
viewUserVote model userVote =
    Html.li []
        [ text (userVote.user.name ++ ": ")
        , viewVote model.room.revealed userVote.vote
        , viewUserStatus model.lastPing userVote
        ]


viewVote revealed vote =
    if revealed then
        text (String.fromInt vote)

    else if vote > 0 then
        text "hidden"

    else
        text "not voted"


viewRevealButton : LoadedRoom -> Html Msg
viewRevealButton model =
    if model.room.revealed then
        Html.p [] [ Html.button [ onClick Reset ] [ text "Reset" ] ]

    else
        Html.p [] [ Html.button [ onClick Reveal ] [ text "Reveal" ] ]


viewLogoutButton : LoadedRoom -> Html Msg
viewLogoutButton model =
    Html.p [] [ Html.button [ onClick Logout ] [ text "Logout" ] ]


viewValueBar : List Int -> Html Msg
viewValueBar values =
    Html.div []
        (List.map
            valueButton
            values
        )


viewUserStatus : Int -> UserVote -> Html msg
viewUserStatus lastPing user =
    let
        diff =
            lastPing - user.ping
    in
    if diff > pingTimeSeconds * 2 then
        text (", disconnected: " ++ String.fromInt diff)

    else
        text (", connected: " ++ String.fromInt diff)


valueButton : Int -> Html Msg
valueButton i =
    Html.button [ Html.Attributes.type_ "button", Html.Events.onClick (CastVote i) ] [ text (String.fromInt i) ]
