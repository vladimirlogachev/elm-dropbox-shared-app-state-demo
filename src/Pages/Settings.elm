module Pages.Settings exposing (Model, Msg, page)

import Auth
import Color
import Effect
import Element exposing (..)
import Element.Font as Font
import Element.Input as Input
import Layouts
import Page exposing (Page)
import RemoteData exposing (RemoteData(..))
import Route exposing (Route)
import Shared
import View exposing (View)


type alias Model =
    {}


type Msg
    = SignOutClicked
    | ReinitializeClicked


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page _ shared _ =
    Page.new
        { init = always init
        , update = update
        , subscriptions = always Sub.none
        , view = view shared
        }
        |> Page.withLayout (always <| Layouts.AppLayout {})



-- INIT


init : ( Model, Effect.Effect Msg )
init =
    ( {}, Effect.none )



-- UPDATE


update : Msg -> Model -> ( Model, Effect.Effect Msg )
update msg model =
    case msg of
        SignOutClicked ->
            ( model, Effect.signOut )

        ReinitializeClicked ->
            ( model, Effect.reinitializeState )



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared _ =
    { title = "Settings | Elm Dropbox Shared App State Demo"
    , attributes = []
    , element = viewContent shared
    }


viewContent : Shared.Model -> Element Msg
viewContent shared =
    column [ width fill, spacing 24 ]
        [ el [ Font.size 18, Font.semiBold ] (text "Settings")
        , column [ spacing 16 ]
            [ Input.button
                [ Font.color Color.red
                , Font.size 14
                ]
                { onPress = Just SignOutClicked
                , label = text "Sign out"
                }
            , case shared.storageContents of
                Success _ ->
                    reinitializeButton

                Failure _ ->
                    reinitializeButton

                _ ->
                    none
            ]
        , el [ Font.color Color.greyMuted, Font.size 12, alignBottom ]
            (text ("Build: " ++ shared.buildVersion))
        ]


reinitializeButton : Element Msg
reinitializeButton =
    Input.button
        [ Font.color Color.red
        , Font.size 14
        ]
        { onPress = Just ReinitializeClicked
        , label = text "Reinitialize app state"
        }
