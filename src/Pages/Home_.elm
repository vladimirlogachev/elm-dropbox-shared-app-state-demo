module Pages.Home_ exposing (Model, Msg, page)

import Dict
import Effect
import Page exposing (Page)
import Route exposing (Route)
import Route.Path
import Shared
import View


type alias Model =
    ()


type alias Msg =
    ()


page : Shared.Model -> Route () -> Page Model Msg
page shared _ =
    Page.new
        { init =
            \_ ->
                ( ()
                , Effect.replaceRoute
                    { path =
                        if shared.auth /= Nothing then
                            Route.Path.Chat

                        else
                            Route.Path.Welcome
                    , query = Dict.empty
                    , hash = Nothing
                    }
                )
        , update = \_ m -> ( m, Effect.none )
        , subscriptions = always Sub.none
        , view = \_ -> View.none
        }
