module Main exposing (..)

import Auth
import Auth.Action
import Browser
import Browser.Navigation
import Effect exposing (Effect)
import Html exposing (Html)
import Json.Decode
import Layout
import Layouts
import Layouts.AppLayout
import Layouts.LandingLayout
import Main.Layouts.Model
import Main.Layouts.Msg
import Main.Pages.Model
import Main.Pages.Msg
import Page
import Pages.Home_
import Pages.Chat
import Pages.Help
import Pages.Settings
import Pages.Welcome
import Pages.NotFound_
import Pages.NotFound_
import Route exposing (Route)
import Route.Path
import Shared
import Task
import Url exposing (Url)
import View exposing (View)


main : Program Json.Decode.Value Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = UrlRequested
        }



-- INIT


type alias Model =
    { key : Browser.Navigation.Key
    , url : Url
    , page : Main.Pages.Model.Model
    , layout : Maybe Main.Layouts.Model.Model
    , shared : Shared.Model
    }


init : Json.Decode.Value -> Url -> Browser.Navigation.Key -> ( Model, Cmd Msg )
init json url key =
    let
        flagsResult : Result Json.Decode.Error Shared.Flags
        flagsResult =
            Json.Decode.decodeValue Shared.decoder json

        ( sharedModel, sharedEffect ) =
            Shared.init flagsResult (Route.fromUrl () url)

        { page, layout } =
            initPageAndLayout { key = key, url = url, shared = sharedModel, layout = Nothing }
    in
    ( { url = url
      , key = key
      , page = Tuple.first page
      , layout = layout |> Maybe.map Tuple.first
      , shared = sharedModel
      }
    , Cmd.batch
          [ Tuple.second page
          , layout |> Maybe.map Tuple.second |> Maybe.withDefault Cmd.none
          , fromSharedEffect { key = key, url = url, shared = sharedModel } sharedEffect
          ]
    )


initLayout : { key : Browser.Navigation.Key, url : Url, shared : Shared.Model, layout : Maybe Main.Layouts.Model.Model } -> Layouts.Layout Msg -> ( Main.Layouts.Model.Model, Cmd Msg )
initLayout model layout =
    case ( layout, model.layout ) of
        ( Layouts.AppLayout props, Just (Main.Layouts.Model.AppLayout existing) ) ->
            ( Main.Layouts.Model.AppLayout existing
            , Cmd.none
            )

        ( Layouts.AppLayout props, _ ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                appLayoutLayout =
                    Layouts.AppLayout.layout props model.shared route

                ( appLayoutLayoutModel, appLayoutLayoutEffect ) =
                    Layout.init appLayoutLayout ()
            in
            ( Main.Layouts.Model.AppLayout { appLayout = appLayoutLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.AppLayout appLayoutLayoutEffect)
            )

        ( Layouts.LandingLayout props, Just (Main.Layouts.Model.LandingLayout existing) ) ->
            ( Main.Layouts.Model.LandingLayout existing
            , Cmd.none
            )

        ( Layouts.LandingLayout props, _ ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                landingLayoutLayout =
                    Layouts.LandingLayout.layout props model.shared route

                ( landingLayoutLayoutModel, landingLayoutLayoutEffect ) =
                    Layout.init landingLayoutLayout ()
            in
            ( Main.Layouts.Model.LandingLayout { landingLayout = landingLayoutLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.LandingLayout landingLayoutLayoutEffect)
            )


initPageAndLayout : { key : Browser.Navigation.Key, url : Url, shared : Shared.Model, layout : Maybe Main.Layouts.Model.Model } -> { page : ( Main.Pages.Model.Model, Cmd Msg ), layout : Maybe ( Main.Layouts.Model.Model, Cmd Msg ) }
initPageAndLayout model =
    case Route.Path.fromUrl model.url of
        Route.Path.Home_ ->
            let
                page : Page.Page Pages.Home_.Model Pages.Home_.Msg
                page =
                    Pages.Home_.page model.shared (Route.fromUrl () model.url)

                ( pageModel, pageEffect ) =
                    Page.init page ()
            in
            { page =
                Tuple.mapBoth
                    Main.Pages.Model.Home_
                    (Effect.map Main.Pages.Msg.Home_ >> fromPageEffect model)
                    ( pageModel, pageEffect )
            , layout =
                Page.layout pageModel page
                    |> Maybe.map (Layouts.map (Main.Pages.Msg.Home_ >> Page))
                    |> Maybe.map (initLayout model)
            }

        Route.Path.Chat ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Chat.Model Pages.Chat.Msg
                        page =
                            Pages.Chat.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.Chat
                            (Effect.map Main.Pages.Msg.Chat >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Chat >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Help ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Help.Model Pages.Help.Msg
                        page =
                            Pages.Help.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.Help
                            (Effect.map Main.Pages.Msg.Help >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Help >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Settings ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Settings.Model Pages.Settings.Msg
                        page =
                            Pages.Settings.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.Settings
                            (Effect.map Main.Pages.Msg.Settings >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Settings >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Welcome ->
            let
                page : Page.Page Pages.Welcome.Model Pages.Welcome.Msg
                page =
                    Pages.Welcome.page model.shared (Route.fromUrl () model.url)

                ( pageModel, pageEffect ) =
                    Page.init page ()
            in
            { page =
                Tuple.mapBoth
                    Main.Pages.Model.Welcome
                    (Effect.map Main.Pages.Msg.Welcome >> fromPageEffect model)
                    ( pageModel, pageEffect )
            , layout =
                Page.layout pageModel page
                    |> Maybe.map (Layouts.map (Main.Pages.Msg.Welcome >> Page))
                    |> Maybe.map (initLayout model)
            }

        Route.Path.NotFound_ ->
            let
                page : Page.Page Pages.NotFound_.Model Pages.NotFound_.Msg
                page =
                    Pages.NotFound_.page model.shared (Route.fromUrl () model.url)

                ( pageModel, pageEffect ) =
                    Page.init page ()
            in
            { page =
                Tuple.mapBoth
                    Main.Pages.Model.NotFound_
                    (Effect.map Main.Pages.Msg.NotFound_ >> fromPageEffect model)
                    ( pageModel, pageEffect )
            , layout =
                Page.layout pageModel page
                    |> Maybe.map (Layouts.map (Main.Pages.Msg.NotFound_ >> Page))
                    |> Maybe.map (initLayout model)
            }


runWhenAuthenticated : { model | shared : Shared.Model, url : Url, key : Browser.Navigation.Key } -> (Auth.User -> ( Main.Pages.Model.Model, Cmd Msg )) -> ( Main.Pages.Model.Model, Cmd Msg )
runWhenAuthenticated model toTuple =
    let
        record =
            runWhenAuthenticatedWithLayout model (\user -> { page = toTuple user, layout = Nothing })
    in
    record.page


runWhenAuthenticatedWithLayout : { model | shared : Shared.Model, url : Url, key : Browser.Navigation.Key } -> (Auth.User -> { page : ( Main.Pages.Model.Model, Cmd Msg ), layout : Maybe ( Main.Layouts.Model.Model, Cmd Msg ) }) -> { page : ( Main.Pages.Model.Model, Cmd Msg ), layout : Maybe ( Main.Layouts.Model.Model, Cmd Msg ) }
runWhenAuthenticatedWithLayout model toRecord =
    let
        authAction : Auth.Action.Action Auth.User
        authAction =
            Auth.onPageLoad model.shared (Route.fromUrl () model.url)

        toCmd : Effect Msg -> Cmd Msg
        toCmd =
            Effect.toCmd
                { key = model.key
                , url = model.url
                , shared = model.shared
                , fromSharedMsg = Shared
                , batch = Batch
                , toCmd = Task.succeed >> Task.perform identity
                }
    in
    case authAction of
        Auth.Action.LoadPageWithUser user ->
            toRecord user

        Auth.Action.LoadCustomPage ->
            { page =
                ( Main.Pages.Model.Loading_
                , Cmd.none
                )
            , layout = Nothing
            }

        Auth.Action.ReplaceRoute options ->
            { page =
                ( Main.Pages.Model.Redirecting_
                , toCmd (Effect.replaceRoute options)
                )
            , layout = Nothing
            }

        Auth.Action.PushRoute options ->
            { page =
                ( Main.Pages.Model.Redirecting_
                , toCmd (Effect.pushRoute options)
                )
            , layout = Nothing
            }

        Auth.Action.LoadExternalUrl externalUrl ->
            { page =
                ( Main.Pages.Model.Redirecting_
                , Browser.Navigation.load externalUrl
                )
            , layout = Nothing
            }



-- UPDATE


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url
    | Page Main.Pages.Msg.Msg
    | Layout Main.Layouts.Msg.Msg
    | Shared Shared.Msg
    | Batch (List Msg)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlRequested (Browser.Internal url) ->
            ( model
            , Browser.Navigation.pushUrl model.key (Url.toString url)
            )

        UrlRequested (Browser.External url) ->
            if String.isEmpty (String.trim url) then
                ( model, Cmd.none )

            else
                ( model
                , Browser.Navigation.load url
                )

        UrlChanged url ->
            if Route.Path.fromUrl url == Route.Path.fromUrl model.url then
                let
                    newModel : Model
                    newModel =
                        { model | url = url }
                in
                ( newModel
                , Cmd.batch
                      [ toPageUrlHookCmd newModel
                            { from = Route.fromUrl () model.url
                            , to = Route.fromUrl () newModel.url
                            }
                      , toLayoutUrlHookCmd model newModel
                            { from = Route.fromUrl () model.url
                            , to = Route.fromUrl () newModel.url
                            }
                      ]
                )

            else
                let
                    { page, layout } =
                        initPageAndLayout { key = model.key, shared = model.shared, layout = model.layout, url = url }

                    ( pageModel, pageCmd ) =
                        page

                    ( layoutModel, layoutCmd ) =
                        case layout of
                            Just ( layoutModel_, layoutCmd_ ) ->
                                ( Just layoutModel_, layoutCmd_ )

                            Nothing ->
                                ( Nothing, Cmd.none )

                    newModel =
                        { model | url = url, page = pageModel, layout = layoutModel }
                in
                ( newModel
                , Cmd.batch
                      [ pageCmd
                      , layoutCmd
                      , toLayoutUrlHookCmd model newModel
                            { from = Route.fromUrl () model.url
                            , to = Route.fromUrl () newModel.url
                            }
                      ]
                )

        Page pageMsg ->
            let
                ( pageModel, pageCmd ) =
                    updateFromPage pageMsg model
            in
            ( { model | page = pageModel }
            , pageCmd
            )

        Layout layoutMsg ->
            let
                ( layoutModel, layoutCmd ) =
                    updateFromLayout layoutMsg model
            in
            ( { model | layout = layoutModel }
            , layoutCmd
            )

        Shared sharedMsg ->
            let
                ( sharedModel, sharedEffect ) =
                    Shared.update (Route.fromUrl () model.url) sharedMsg model.shared

                ( oldAction, newAction ) =
                    ( Auth.onPageLoad model.shared (Route.fromUrl () model.url)
                    , Auth.onPageLoad sharedModel (Route.fromUrl () model.url)
                    )
            in
            if isAuthProtected (Route.fromUrl () model.url).path && (hasActionTypeChanged oldAction newAction) then
                let
                    { layout, page } =
                        initPageAndLayout { key = model.key, shared = sharedModel, url = model.url, layout = model.layout }

                    ( pageModel, pageCmd ) =
                        page

                    ( layoutModel, layoutCmd ) =
                        ( layout |> Maybe.map Tuple.first
                        , layout |> Maybe.map Tuple.second |> Maybe.withDefault Cmd.none
                        )
                in
                ( { model | shared = sharedModel, page = pageModel, layout = layoutModel }
                , Cmd.batch
                      [ pageCmd
                      , layoutCmd
                      , fromSharedEffect { model | shared = sharedModel } sharedEffect
                      ]
                )

            else
                ( { model | shared = sharedModel }
                , fromSharedEffect { model | shared = sharedModel } sharedEffect
                )

        Batch messages ->
            ( model
            , messages
                  |> List.map (Task.succeed >> Task.perform identity)
                  |> Cmd.batch
            )


updateFromPage : Main.Pages.Msg.Msg -> Model -> ( Main.Pages.Model.Model, Cmd Msg )
updateFromPage msg model =
    case ( msg, model.page ) of
        ( Main.Pages.Msg.Home_ pageMsg, Main.Pages.Model.Home_ pageModel ) ->
            Tuple.mapBoth
                Main.Pages.Model.Home_
                (Effect.map Main.Pages.Msg.Home_ >> fromPageEffect model)
                (Page.update (Pages.Home_.page model.shared (Route.fromUrl () model.url)) pageMsg pageModel)

        ( Main.Pages.Msg.Chat pageMsg, Main.Pages.Model.Chat pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.Chat
                        (Effect.map Main.Pages.Msg.Chat >> fromPageEffect model)
                        (Page.update (Pages.Chat.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Help pageMsg, Main.Pages.Model.Help pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.Help
                        (Effect.map Main.Pages.Msg.Help >> fromPageEffect model)
                        (Page.update (Pages.Help.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Settings pageMsg, Main.Pages.Model.Settings pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.Settings
                        (Effect.map Main.Pages.Msg.Settings >> fromPageEffect model)
                        (Page.update (Pages.Settings.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Welcome pageMsg, Main.Pages.Model.Welcome pageModel ) ->
            Tuple.mapBoth
                Main.Pages.Model.Welcome
                (Effect.map Main.Pages.Msg.Welcome >> fromPageEffect model)
                (Page.update (Pages.Welcome.page model.shared (Route.fromUrl () model.url)) pageMsg pageModel)

        ( Main.Pages.Msg.NotFound_ pageMsg, Main.Pages.Model.NotFound_ pageModel ) ->
            Tuple.mapBoth
                Main.Pages.Model.NotFound_
                (Effect.map Main.Pages.Msg.NotFound_ >> fromPageEffect model)
                (Page.update (Pages.NotFound_.page model.shared (Route.fromUrl () model.url)) pageMsg pageModel)

        _ ->
            ( model.page
            , Cmd.none
            )


updateFromLayout : Main.Layouts.Msg.Msg -> Model -> ( Maybe Main.Layouts.Model.Model, Cmd Msg )
updateFromLayout msg model =
    let
        route : Route ()
        route =
            Route.fromUrl () model.url
    in
    case ( toLayoutFromPage model, model.layout, msg ) of
        ( Just (Layouts.AppLayout props), Just (Main.Layouts.Model.AppLayout layoutModel), Main.Layouts.Msg.AppLayout layoutMsg ) ->
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.AppLayout { layoutModel | appLayout = newModel }))
                (Effect.map Main.Layouts.Msg.AppLayout >> fromLayoutEffect model)
                (Layout.update (Layouts.AppLayout.layout props model.shared route) layoutMsg layoutModel.appLayout)

        ( Just (Layouts.LandingLayout props), Just (Main.Layouts.Model.LandingLayout layoutModel), Main.Layouts.Msg.LandingLayout layoutMsg ) ->
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.LandingLayout { layoutModel | landingLayout = newModel }))
                (Effect.map Main.Layouts.Msg.LandingLayout >> fromLayoutEffect model)
                (Layout.update (Layouts.LandingLayout.layout props model.shared route) layoutMsg layoutModel.landingLayout)

        _ ->
            ( model.layout
            , Cmd.none
            )


toLayoutFromPage : Model -> Maybe (Layouts.Layout Msg)
toLayoutFromPage model =
    case model.page of
        Main.Pages.Model.Home_ pageModel ->
            Route.fromUrl () model.url
                |> Pages.Home_.page model.shared
                |> Page.layout pageModel
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Home_ >> Page))

        Main.Pages.Model.Chat pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Chat.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Chat >> Page))

        Main.Pages.Model.Help pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Help.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Help >> Page))

        Main.Pages.Model.Settings pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Settings.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Settings >> Page))

        Main.Pages.Model.Welcome pageModel ->
            Route.fromUrl () model.url
                |> Pages.Welcome.page model.shared
                |> Page.layout pageModel
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Welcome >> Page))

        Main.Pages.Model.NotFound_ pageModel ->
            Route.fromUrl () model.url
                |> Pages.NotFound_.page model.shared
                |> Page.layout pageModel
                |> Maybe.map (Layouts.map (Main.Pages.Msg.NotFound_ >> Page))

        Main.Pages.Model.Redirecting_ ->
            Nothing

        Main.Pages.Model.Loading_ ->
            Nothing


toAuthProtectedPage : Model -> (Auth.User -> Shared.Model -> Route params -> Page.Page model msg) -> Route params -> Maybe (Page.Page model msg)
toAuthProtectedPage model toPage route =
    case Auth.onPageLoad model.shared (Route.fromUrl () model.url) of
        Auth.Action.LoadPageWithUser user ->
            Just (toPage user model.shared route)

        _ ->
            Nothing


hasActionTypeChanged : Auth.Action.Action user -> Auth.Action.Action user -> Bool
hasActionTypeChanged oldAction newAction =
    case ( newAction, oldAction ) of
        ( Auth.Action.LoadPageWithUser _, Auth.Action.LoadPageWithUser _ ) ->
            False

        ( Auth.Action.LoadCustomPage, Auth.Action.LoadCustomPage ) ->
            False

        ( Auth.Action.ReplaceRoute _, Auth.Action.ReplaceRoute _ ) ->
            False

        ( Auth.Action.PushRoute _, Auth.Action.PushRoute _ ) ->
            False

        ( Auth.Action.LoadExternalUrl _, Auth.Action.LoadExternalUrl _ ) ->
            False

        ( _,  _ ) ->
            True


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        subscriptionsFromPage : Sub Msg
        subscriptionsFromPage =
            case model.page of
                Main.Pages.Model.Home_ pageModel ->
                    Page.subscriptions (Pages.Home_.page model.shared (Route.fromUrl () model.url)) pageModel
                        |> Sub.map Main.Pages.Msg.Home_
                        |> Sub.map Page

                Main.Pages.Model.Chat pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Chat.page user model.shared (Route.fromUrl () model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Chat
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Help pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Help.page user model.shared (Route.fromUrl () model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Help
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Settings pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Settings.page user model.shared (Route.fromUrl () model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Settings
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Welcome pageModel ->
                    Page.subscriptions (Pages.Welcome.page model.shared (Route.fromUrl () model.url)) pageModel
                        |> Sub.map Main.Pages.Msg.Welcome
                        |> Sub.map Page

                Main.Pages.Model.NotFound_ pageModel ->
                    Page.subscriptions (Pages.NotFound_.page model.shared (Route.fromUrl () model.url)) pageModel
                        |> Sub.map Main.Pages.Msg.NotFound_
                        |> Sub.map Page

                Main.Pages.Model.Redirecting_ ->
                    Sub.none

                Main.Pages.Model.Loading_ ->
                    Sub.none

        maybeLayout : Maybe (Layouts.Layout Msg)
        maybeLayout =
            toLayoutFromPage model

        route : Route ()
        route =
            Route.fromUrl () model.url

        subscriptionsFromLayout : Sub Msg
        subscriptionsFromLayout =
            case ( maybeLayout, model.layout ) of
                ( Just (Layouts.AppLayout props), Just (Main.Layouts.Model.AppLayout layoutModel) ) ->
                    Layout.subscriptions (Layouts.AppLayout.layout props model.shared route) layoutModel.appLayout
                        |> Sub.map Main.Layouts.Msg.AppLayout
                        |> Sub.map Layout

                ( Just (Layouts.LandingLayout props), Just (Main.Layouts.Model.LandingLayout layoutModel) ) ->
                    Layout.subscriptions (Layouts.LandingLayout.layout props model.shared route) layoutModel.landingLayout
                        |> Sub.map Main.Layouts.Msg.LandingLayout
                        |> Sub.map Layout

                _ ->
                    Sub.none
    in
    Sub.batch
        [ Shared.subscriptions route model.shared
              |> Sub.map Shared
        , subscriptionsFromPage
        , subscriptionsFromLayout
        ]



-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        view_ : View Msg
        view_ =
            toView model
    in
    View.toBrowserDocument
        { shared = model.shared
        , route = Route.fromUrl () model.url
        , view = view_
        }


toView : Model -> View Msg
toView model =
    let
        route : Route ()
        route =
            Route.fromUrl () model.url
    in
    case ( toLayoutFromPage model, model.layout ) of
        ( Just (Layouts.AppLayout props), Just (Main.Layouts.Model.AppLayout layoutModel) ) ->
            Layout.view
                (Layouts.AppLayout.layout props model.shared route)
                { model = layoutModel.appLayout
                , toContentMsg = Main.Layouts.Msg.AppLayout >> Layout
                , content = viewPage model
                }

        ( Just (Layouts.LandingLayout props), Just (Main.Layouts.Model.LandingLayout layoutModel) ) ->
            Layout.view
                (Layouts.LandingLayout.layout props model.shared route)
                { model = layoutModel.landingLayout
                , toContentMsg = Main.Layouts.Msg.LandingLayout >> Layout
                , content = viewPage model
                }

        _ ->
            viewPage model


viewPage : Model -> View Msg
viewPage model =
    case model.page of
        Main.Pages.Model.Home_ pageModel ->
            Page.view (Pages.Home_.page model.shared (Route.fromUrl () model.url)) pageModel
                |> View.map Main.Pages.Msg.Home_
                |> View.map Page

        Main.Pages.Model.Chat pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Chat.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.Chat
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Help pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Help.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.Help
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Settings pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Settings.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.Settings
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Welcome pageModel ->
            Page.view (Pages.Welcome.page model.shared (Route.fromUrl () model.url)) pageModel
                |> View.map Main.Pages.Msg.Welcome
                |> View.map Page

        Main.Pages.Model.NotFound_ pageModel ->
            Page.view (Pages.NotFound_.page model.shared (Route.fromUrl () model.url)) pageModel
                |> View.map Main.Pages.Msg.NotFound_
                |> View.map Page

        Main.Pages.Model.Redirecting_ ->
            View.none

        Main.Pages.Model.Loading_ ->
            Auth.viewCustomPage model.shared (Route.fromUrl () model.url)
                |> View.map never



-- INTERNALS


fromPageEffect : { model | key : Browser.Navigation.Key, url : Url, shared : Shared.Model } -> Effect Main.Pages.Msg.Msg -> Cmd Msg
fromPageEffect model effect =
    Effect.toCmd
        { key = model.key
        , url = model.url
        , shared = model.shared
        , fromSharedMsg = Shared
        , batch = Batch
        , toCmd = Task.succeed >> Task.perform identity
        }
        (Effect.map Page effect)


fromLayoutEffect : { model | key : Browser.Navigation.Key, url : Url, shared : Shared.Model } -> Effect Main.Layouts.Msg.Msg -> Cmd Msg
fromLayoutEffect model effect =
    Effect.toCmd
        { key = model.key
        , url = model.url
        , shared = model.shared
        , fromSharedMsg = Shared
        , batch = Batch
        , toCmd = Task.succeed >> Task.perform identity
        }
        (Effect.map Layout effect)


fromSharedEffect : { model | key : Browser.Navigation.Key, url : Url, shared : Shared.Model } -> Effect Shared.Msg -> Cmd Msg
fromSharedEffect model effect =
    Effect.toCmd
        { key = model.key
        , url = model.url
        , shared = model.shared
        , fromSharedMsg = Shared
        , batch = Batch
        , toCmd = Task.succeed >> Task.perform identity
        }
        (Effect.map Shared effect)



-- URL HOOKS FOR PAGES


toPageUrlHookCmd : Model -> { from : Route (), to : Route () } -> Cmd Msg
toPageUrlHookCmd model routes =
    let
        toCommands messages =
            messages
                |> List.map (Task.succeed >> Task.perform identity)
                |> Cmd.batch
    in
    case model.page of
        Main.Pages.Model.Home_ pageModel ->
            Page.toUrlMessages routes (Pages.Home_.page model.shared (Route.fromUrl () model.url))
                |> List.map Main.Pages.Msg.Home_
                |> List.map Page
                |> toCommands

        Main.Pages.Model.Chat pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Chat.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.Chat
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Help pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Help.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.Help
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Settings pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Settings.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.Settings
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Welcome pageModel ->
            Page.toUrlMessages routes (Pages.Welcome.page model.shared (Route.fromUrl () model.url))
                |> List.map Main.Pages.Msg.Welcome
                |> List.map Page
                |> toCommands

        Main.Pages.Model.NotFound_ pageModel ->
            Page.toUrlMessages routes (Pages.NotFound_.page model.shared (Route.fromUrl () model.url))
                |> List.map Main.Pages.Msg.NotFound_
                |> List.map Page
                |> toCommands

        Main.Pages.Model.Redirecting_ ->
            Cmd.none

        Main.Pages.Model.Loading_ ->
            Cmd.none


toLayoutUrlHookCmd : Model -> Model -> { from : Route (), to : Route () } -> Cmd Msg
toLayoutUrlHookCmd oldModel model routes =
    let
        toCommands messages =
            if shouldFireUrlChangedEvents then
                messages
                    |> List.map (Task.succeed >> Task.perform identity)
                    |> Cmd.batch

            else
                Cmd.none

        shouldFireUrlChangedEvents =
            hasNavigatedWithinNewLayout
                { from = toLayoutFromPage oldModel
                , to = toLayoutFromPage model
                }

        route =
            Route.fromUrl () model.url
    in
    case ( toLayoutFromPage model, model.layout ) of
        ( Just (Layouts.AppLayout props), Just (Main.Layouts.Model.AppLayout layoutModel) ) ->
            Layout.toUrlMessages routes (Layouts.AppLayout.layout props model.shared route)
                |> List.map Main.Layouts.Msg.AppLayout
                |> List.map Layout
                |> toCommands

        ( Just (Layouts.LandingLayout props), Just (Main.Layouts.Model.LandingLayout layoutModel) ) ->
            Layout.toUrlMessages routes (Layouts.LandingLayout.layout props model.shared route)
                |> List.map Main.Layouts.Msg.LandingLayout
                |> List.map Layout
                |> toCommands

        _ ->
            Cmd.none


hasNavigatedWithinNewLayout : { from : Maybe (Layouts.Layout msg), to : Maybe (Layouts.Layout msg) } -> Bool
hasNavigatedWithinNewLayout { from, to } =
    let
        isRelated maybePair =
            case maybePair of
                Just ( Layouts.AppLayout _, Layouts.AppLayout _ ) ->
                    True

                Just ( Layouts.LandingLayout _, Layouts.LandingLayout _ ) ->
                    True

                _ ->
                    False
    in
    List.any isRelated
        [ Maybe.map2 Tuple.pair from to
        , Maybe.map2 Tuple.pair to from
        ]


isAuthProtected : Route.Path.Path -> Bool
isAuthProtected routePath =
    case routePath of
        Route.Path.Home_ ->
            False

        Route.Path.Chat ->
            True

        Route.Path.Help ->
            True

        Route.Path.Settings ->
            True

        Route.Path.Welcome ->
            False

        Route.Path.NotFound_ ->
            False
