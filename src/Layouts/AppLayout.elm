module Layouts.AppLayout exposing (Model, Msg, Props, layout)

import Color
import Effect exposing (Effect)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import GridLayout2
import Layout exposing (Layout)
import Route exposing (Route)
import Route.Path
import Shared
import Shared.Model exposing (Toast, ToastType(..))
import Shared.Msg
import TextStyle
import View exposing (View)


type alias Props =
    {}


layout : Props -> Shared.Model -> Route () -> Layout () Model Msg contentMsg
layout _ shared route =
    Layout.new
        { init = init
        , update = update
        , view = view shared route
        , subscriptions = always Sub.none
        }



-- MODEL


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init _ =
    ( {}, Effect.none )



-- UPDATE


type Msg
    = DismissToastClicked Int


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        DismissToastClicked toastId ->
            ( model, Effect.sendSharedMsg (Shared.Msg.DismissToast toastId) )



-- VIEW


view : Shared.Model -> Route () -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
view shared route { toContentMsg, content } =
    { title = content.title
    , attributes =
        GridLayout2.bodyAttributes shared.layout
            ++ TextStyle.body
            ++ content.attributes
            ++ (if List.isEmpty shared.toasts then
                    []

                else
                    [ inFront (viewToasts toContentMsg shared.toasts) ]
               )
    , element =
        column (height fill :: GridLayout2.layoutOuterAttributes)
            [ el
                [ width fill
                , height (px 5)
                , Background.color
                    (if not (List.isEmpty shared.inFlightActions) || shared.reinitializeInFlight then
                        Color.amber

                     else
                        Color.white
                    )
                ]
                none
            , column (height fill :: GridLayout2.layoutInnerAttributes shared.layout)
                [ case shared.auth of
                    Just _ ->
                        viewNav route.path

                    Nothing ->
                        none
                , content.element
                ]
            ]
    }


viewNav : Route.Path.Path -> Element contentMsg
viewNav currentPath =
    row [ spacing 16, paddingEach { top = 8, right = 0, bottom = 8, left = 0 } ]
        [ viewNavLink currentPath Route.Path.Chat "Chat"
        , viewNavLink currentPath Route.Path.Help "Help"
        , viewNavLink currentPath Route.Path.Settings "Settings"
        ]


viewNavLink : Route.Path.Path -> Route.Path.Path -> String -> Element contentMsg
viewNavLink currentPath linkPath caption =
    link
        [ Font.size 14
        , Font.color
            (if currentPath == linkPath then
                Color.silver

             else
                Color.primaryBlue
            )
        ]
        { url = Route.Path.toString linkPath
        , label = text caption
        }


viewToasts : (Msg -> contentMsg) -> List Toast -> Element contentMsg
viewToasts toContentMsg toasts =
    column
        [ centerX
        , paddingXY 0 16
        , spacing 8
        ]
        (List.map (viewToast toContentMsg) toasts)


viewToast : (Msg -> contentMsg) -> Toast -> Element contentMsg
viewToast toContentMsg toast =
    el
        [ Background.color
            (case toast.toastType of
                SuccessToast ->
                    Color.green

                ErrorToast ->
                    Color.red
            )
        , Font.color Color.white
        , Font.size 14
        , paddingXY 20 12
        , Border.rounded 4
        , pointer
        , Events.onClick (toContentMsg (DismissToastClicked toast.id))
        ]
        (text toast.message)
