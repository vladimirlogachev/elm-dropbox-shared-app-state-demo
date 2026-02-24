module Pages.Chat exposing (Model, Msg, page)

import AppState exposing (AppState, ChatRecord, PendingAction(..), listMessages)
import Auth
import Color
import Effect
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html.Events
import Json.Decode as Json
import Layouts
import Page exposing (Page)
import RemoteData exposing (RemoteData(..))
import Route exposing (Route)
import Shared
import Task
import TextStyle
import Time exposing (Posix)
import Utils exposing (parseDevice)
import View exposing (View)


type alias Model =
    { messageInput : String
    }


type Msg
    = UpdateMessageInput String
    | SendMessageClicked
    | MessageSent Posix


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page _ shared _ =
    Page.new
        { init = always init
        , update = update shared
        , subscriptions = always Sub.none
        , view = view shared
        }
        |> Page.withLayout (always <| Layouts.AppLayout {})



-- INIT


init : ( Model, Effect.Effect Msg )
init =
    ( { messageInput = "" }, Effect.none )



-- UPDATE


update : Shared.Model -> Msg -> Model -> ( Model, Effect.Effect Msg )
update shared msg model =
    case msg of
        UpdateMessageInput s ->
            ( { model | messageInput = s }, Effect.none )

        SendMessageClicked ->
            if String.trim model.messageInput == "" then
                ( model, Effect.none )

            else
                ( model, Effect.sendCmd (Task.perform MessageSent Time.now) )

        MessageSent posix ->
            case shared.storageContents of
                Success _ ->
                    let
                        record : ChatRecord
                        record =
                            { userAgent = shared.userAgent
                            , message = String.trim model.messageInput
                            , timestamp = posix
                            }
                    in
                    ( { model | messageInput = "" }
                    , Effect.saveData (AddMessage record)
                    )

                _ ->
                    ( model, Effect.none )



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = "Chat | Elm Dropbox Shared App State Demo"
    , attributes = []
    , element = viewContent shared model
    }


viewContent : Shared.Model -> Model -> Element Msg
viewContent shared model =
    case shared.storageContents of
        Success sc ->
            viewChat sc model

        Loading ->
            el [ centerX, centerY ] (text "Loading...")

        Failure err ->
            column [ spacing 16, width fill ]
                [ el [] (text err) ]

        NotAsked ->
            el [] (text "Not loaded")


viewChat : AppState -> Model -> Element Msg
viewChat sc model =
    let
        isEmpty : Bool
        isEmpty =
            String.trim model.messageInput == ""
    in
    column [ width fill, spacing 16, height fill ]
        [ row [ width fill, spacing 8 ]
            [ Input.text
                [ width fill, onEnter SendMessageClicked ]
                { onChange = UpdateMessageInput
                , text = model.messageInput
                , placeholder = Just (Input.placeholder [] (text "Type a message..."))
                , label = Input.labelHidden "Message"
                }
            , Input.button
                ([ paddingXY 16 10
                 , Border.rounded 4
                 ]
                    ++ (if isEmpty then
                            [ Font.color Color.silver ]

                        else
                            [ Font.color Color.green ]
                       )
                )
                { onPress =
                    if isEmpty then
                        Nothing

                    else
                        Just SendMessageClicked
                , label = text "Send"
                }
            ]
        , column [ width fill, spacing 8 ]
            (listMessages sc |> List.map viewMessage)
        ]


onEnter : msg -> Attribute msg
onEnter msg =
    htmlAttribute
        (Html.Events.on "keydown"
            (Json.field "key" Json.string
                |> Json.andThen
                    (\key ->
                        if key == "Enter" then
                            Json.succeed msg

                        else
                            Json.fail "not enter"
                    )
            )
        )


viewMessage : ChatRecord -> Element msg
viewMessage record =
    column
        [ width fill
        , padding 12
        , spacing 4
        , Background.color Color.greyLight
        , Border.rounded 4
        ]
        [ paragraph [] [ text record.message ]
        , el TextStyle.secondary (text (parseDevice record.userAgent))
        ]
