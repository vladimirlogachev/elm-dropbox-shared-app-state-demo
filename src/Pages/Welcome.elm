module Pages.Welcome exposing (Model, Msg, page)

import Color
import Effect
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Layouts
import Page exposing (Page)
import Route exposing (Route)
import Route.Path
import Shared
import TextStyle
import View exposing (View)


type alias Model =
    ()


type alias Msg =
    ()


page : Shared.Model -> Route () -> Page Model Msg
page _ _ =
    Page.new
        { init = always init
        , update = \_ m -> ( m, Effect.none )
        , subscriptions = always Sub.none
        , view = always view
        }
        |> Page.withLayout (always <| Layouts.LandingLayout {})



-- INIT


init : ( Model, Effect.Effect Msg )
init =
    ( (), Effect.none )



-- VIEW


view : View Msg
view =
    { title = "Elm Dropbox Shared App State Demo"
    , attributes = []
    , element =
        column [ centerX, centerY, spacing 24 ]
            [ el (centerX :: TextStyle.header.attrs) (text "Elm Dropbox Shared App State Demo")
            , link
                [ centerX
                , Background.color Color.primaryBlue
                , Font.color Color.white
                , paddingXY 24 12
                , Border.rounded 4
                ]
                { url = Route.Path.toString Route.Path.Chat
                , label = text "Open app"
                }
            ]
    }
