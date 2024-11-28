port module Pokertool exposing (..)

import Browser exposing (UrlRequest)
import Dict
import Dict.Extra
import FormatNumber exposing (format)
import FormatNumber.Locales exposing (usLocale)
import Html exposing (Html, text)
import Html.Attributes exposing (class, href, type_, value)
import Html.Events exposing (onClick)
import Http
import Json.Decode exposing (Decoder, field, string)
import Random
import Room exposing (Room, User, UserVote)
import Time exposing (Posix, posixToMillis)
import UUID exposing (UUID)
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


emptyLoadingRoom : Maybe String -> Model
emptyLoadingRoom roomId =
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
    | Logout (Maybe String) User
    | Ping Posix
    | LoggedOut (Result Http.Error Room)



-- PORTS


port storeUserPort : User -> Cmd msg


port loadUserPort : (String -> msg) -> Sub msg


port logoutPort : () -> Cmd msg


pingTimeSeconds =
    5


init : { roomId : Maybe String, user : Maybe User } -> ( Model, Cmd Msg )
init flags =
    case flags.roomId of
        Just roomId ->
            case flags.user of
                Just user ->
                    ( initLoadingRoom flags.roomId flags.user, Room.join (Just roomId) user GotRoom )

                Nothing ->
                    ( initLoadingRoom flags.roomId flags.user, generateUserUUID )

        Nothing ->
            ( initLoadingRoom flags.roomId flags.user, generateUserUUID )


initLoadingRoom roomId user =
    LoadingRoomState { inputUser = "", roomId = roomId, user = user, userUuid = "", inputRoomId = "" }


initFullRoom room user =
    LoadedRoom room user [ 1, 2, 3, 5, 8, 13, 21 ] 0


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch [ loadUserPort userDecoder, Time.every (pingTimeSeconds * 1000) Ping ]


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
                            ( FullLoadedRoomState (initFullRoom room room.user), storeUserPort room.user )

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
                    ( LoadingRoomState { loadingRoom | user = Just user }, storeUserPort user )

                Logout roomId user ->
                    onLogout roomId user

                LoggedOut _ ->
                    onLoggedOut

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

                Logout roomId user ->
                    onLogout roomId user

                LoggedOut _ ->
                    onLoggedOut

                Ping posix ->
                    ( FullLoadedRoomState { loadedRoom | lastPing = posixToMillis posix // 1000 }, Room.ping loadedRoom.room.id loadedRoom.user GotRoom )

                _ ->
                    ( model, Cmd.none )


onLogout : Maybe String -> User -> ( Model, Cmd Msg )
onLogout maybeRoomId user =
    case maybeRoomId of
        Nothing ->
            onLoggedOut

        Just roomId ->
            ( emptyLoadingRoom Nothing, Room.leave roomId user LoggedOut )


onLoggedOut =
    ( emptyLoadingRoom Nothing, logoutPort () )


view : Model -> Html Msg
view model =
    case model of
        LoadingRoomState loadingRoom ->
            Views.page (viewLogoutLink loadingRoom.user loadingRoom.roomId) <| askUser loadingRoom

        FullLoadedRoomState loadedRoom ->
            Views.page (viewLogoutLink (Just loadedRoom.user) (Just loadedRoom.room.id)) <| viewRoom loadedRoom


viewLogoutLink : Maybe User -> Maybe String -> Html Msg
viewLogoutLink user roomId =
    case user of
        Nothing ->
            Html.div [] []

        Just u ->
            Html.div [ class "" ]
                [ text ("Hello " ++ u.name ++ ", ")
                , Views.linkButton (Logout roomId u) "logout" True
                ]


askUser : LoadingRoom -> Html Msg
askUser model =
    case model.user of
        Nothing ->
            case model.roomId of
                Just roomId ->
                    Views.centered
                        [ Views.insertUserName InputUser model.inputUser
                        , Views.button JoinRoom "Join" True
                        ]

                Nothing ->
                    Views.centered
                        [ Views.insertUserName InputUser model.inputUser
                        , Views.hint "A valid user name must be at least 3 character long"
                        , Views.button Login "Login" (isValidUser model.inputUser)
                        ]

        Just user ->
            Views.centered
                [ Html.p [ class "mb-0" ] [ Views.button CreateRoom "Create a New room" True ]
                , Html.p [ class "text-center mt-1 mb-1" ] [ text "or" ]
                , Views.textInput { placeholder = "Paste a valid Room Id" } InputRoomId model.inputRoomId
                , Html.p [ class "mt-1" ] [ Views.button CreateRoom "Join an Existing One" (isValidRoomId model.inputRoomId) ]
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
    Views.centeredLarge
        [ viewRoomLink model.room
        , viewValueBar model.values (currentUserVote model)
        , viewUserVotes model
        , viewRevealButton model
        ]


currentUserVote : LoadedRoom -> Int
currentUserVote model =
    model.room.members
        |> List.filter (\u -> u.user.id == model.user.id)
        |> List.head
        |> Maybe.withDefault (UserVote (User "" "") 0 0)
        |> .vote


viewRoomLink room =
    Html.p []
        [ text "Share Room Link: "
        , Html.a [ class "font-monospace", href ("?id=" ++ room.id) ] [ text room.id ]
        ]


viewUserVotes : LoadedRoom -> Html msg
viewUserVotes model =
    let
        sortBy =
            if model.room.revealed then
                sortByVote

            else
                sortByName
    in
    Html.ul [ class "list-group list-group-flush mt-5" ] (List.map (viewUserVote model) (model.room.members |> sortBy))


sortByVote : List UserVote -> List UserVote
sortByVote members =
    members
        |> List.sortBy (\t -> t.user.id)
        |> List.sortBy (\t -> t.user.name)
        |> List.sortBy (\t -> -t.vote)


sortByName : List UserVote -> List UserVote
sortByName members =
    members
        |> List.sortBy (\t -> t.user.id)
        |> List.sortBy (\t -> t.user.name)


viewUserVote : LoadedRoom -> UserVote -> Html msg
viewUserVote model userVote =
    Html.li [ class "list-group-item d-flex justify-content-between align-items-start fs-5" ]
        [ Html.div [ class "ms-2 me-auto" ] [ Html.div [ class "fw-bold" ] [ viewUserStatus model.lastPing userVote, text userVote.user.name ] ]
        , viewVote model.room.revealed userVote.vote
        ]


viewVote revealed vote =
    if revealed then
        text (String.fromInt vote)

    else if vote > 0 then
        Html.i [ class "bi bi-check-lg text-success" ] []

    else
        Html.i [ class "bi bi-dash" ] []


viewRevealButton : LoadedRoom -> Html Msg
viewRevealButton model =
    if model.room.revealed then
        Html.div [ class "mt-3" ]
            [ viewResults model
            , Views.button Reset "Reset" True
            ]

    else
        Html.p [ class "mt-5" ] [ Views.button Reveal "Reveal" True ]


viewResults : LoadedRoom -> Html Msg
viewResults model =
    Html.div []
        [ Html.hr [] []
        , Html.h3 [] [ text "Results" ]
        , Html.ul [ class "list-group list-group-flush" ]
            [ Html.li [ class "list-group-item d-flex justify-content-between align-items-start fs-5" ]
                [ Html.div [ class "ms-2 me-auto" ] [ Html.div [ class "fw-bold" ] [ text "Majority of: " ] ]
                , text (majorityOf model.room.members |> String.fromInt)
                ]
            , Html.li [ class "list-group-item d-flex justify-content-between align-items-start fs-5" ]
                [ Html.div [ class "ms-2 me-auto" ] [ Html.div [ class "fw-bold" ] [ text "Mean: " ] ]
                , text (meanOf model.room.members |> format usLocale)
                ]
            ]
        ]


majorityOf : List UserVote -> Int
majorityOf votes =
    Dict.Extra.groupBy .vote votes
        |> Dict.map (\k -> List.length)
        |> Dict.toList
        |> List.sortBy Tuple.second
        |> List.reverse
        |> List.head
        |> Maybe.withDefault ( 0, 0 )
        |> Tuple.first


meanOf : List UserVote -> Float
meanOf votes =
    let
        sum =
            votes
                |> List.map .vote
                |> List.sum
                |> toFloat
    in
    sum / (List.length votes |> toFloat)


viewValueBar : List Int -> Int -> Html Msg
viewValueBar values userVote =
    Html.div [ class "row" ]
        (values
            |> List.map (valueButton userVote)
        )


viewUserStatus : Int -> UserVote -> Html msg
viewUserStatus lastPing user =
    let
        disconnected =
            (lastPing - user.ping) > pingTimeSeconds * 2
    in
    if disconnected then
        Html.span []
            [ Html.i [ class "bi bi-lightning-charge-fill text-danger" ] []
            ]

    else
        Html.span [] []


valueButton : Int -> Int -> Html Msg
valueButton userVote vote =
    let
        className =
            if userVote == vote then
                "btn-info"

            else
                "btn-outline-info"
    in
    Html.div [ class "col" ]
        [ Html.button
            [ type_ "button"
            , class ("btn " ++ className ++ " shadow w-100 fs-1")
            , onClick (CastVote vote)
            ]
            [ text (String.fromInt vote) ]
        ]
