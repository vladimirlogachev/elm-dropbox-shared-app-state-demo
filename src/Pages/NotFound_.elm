module Pages.NotFound_ exposing (Model, Msg, page)

import Dict
import Effect exposing (Effect)
import Page exposing (Page)
import Route exposing (Route)
import Route.Path
import Shared
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page _ _ =
    Page.new
        { init = init
        , update = \_ m -> ( m, Effect.none )
        , subscriptions = always Sub.none
        , view = view
        }



-- INIT


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init () =
    ( {}
    , Effect.replaceRoute
        { path = Route.Path.Home_
        , query = Dict.empty
        , hash = Nothing
        }
    )



-- UPDATE


type alias Msg =
    ()



-- VIEW


view : Model -> View Msg
view _ =
    View.fromString "Redirecting..."
