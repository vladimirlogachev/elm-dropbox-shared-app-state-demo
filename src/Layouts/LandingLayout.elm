module Layouts.LandingLayout exposing (Model, Msg, Props, layout)

import Effect exposing (Effect)
import Element exposing (..)
import GridLayout2
import Layout exposing (Layout)
import Route exposing (Route)
import Shared
import TextStyle
import View exposing (View)


type alias Props =
    {}


layout : Props -> Shared.Model -> Route () -> Layout () Model Msg contentMsg
layout _ shared _ =
    Layout.new
        { init = init
        , update = update
        , view = view shared
        , subscriptions = always Sub.none
        }



-- MODEL


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init _ =
    ( {}, Effect.none )



-- UPDATE


type alias Msg =
    Never


update : Msg -> Model -> ( Model, Effect Msg )
update msg _ =
    never msg



-- VIEW


view : Shared.Model -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
view shared { content } =
    { title = content.title
    , attributes =
        GridLayout2.bodyAttributes shared.layout
            ++ TextStyle.body
            ++ content.attributes
    , element =
        column (height fill :: GridLayout2.layoutOuterAttributes)
            [ column (height fill :: GridLayout2.layoutInnerAttributes shared.layout)
                [ content.element ]
            ]
    }
