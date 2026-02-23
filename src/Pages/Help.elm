module Pages.Help exposing (Model, Msg, page)

import Auth
import Effect
import Element exposing (..)
import Http
import Layouts
import Markdown
import Page exposing (Page)
import RemoteData exposing (RemoteData(..))
import Route exposing (Route)
import Shared
import View exposing (View)


type alias Model =
    { document : RemoteData Http.Error String }


type Msg
    = GotDocument (Result Http.Error String)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page _ _ _ =
    Page.new
        { init = always init
        , update = update
        , subscriptions = always Sub.none
        , view = view
        }
        |> Page.withLayout (always <| Layouts.AppLayout {})



-- INIT


init : ( Model, Effect.Effect Msg )
init =
    ( { document = Loading }
    , Http.get
        { url = "/user-manual.md"
        , expect = Http.expectString GotDocument
        }
        |> Effect.sendCmd
    )



-- UPDATE


update : Msg -> Model -> ( Model, Effect.Effect Msg )
update msg model =
    case msg of
        GotDocument res ->
            ( { model | document = RemoteData.fromResult res }, Effect.none )



-- VIEW


view : Model -> View Msg
view model =
    { title = "Help | Elm Dropbox Shared App State Demo"
    , attributes = []
    , element =
        column [ width fill, spacing 24 ]
            [ case model.document of
                NotAsked ->
                    none

                Loading ->
                    el [] (text "Loading...")

                Failure _ ->
                    el [] (text "Failed to load the document")

                Success str ->
                    Markdown.preparedMarkdown str
            ]
    }
