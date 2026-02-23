module Shared exposing
    ( Flags
    , Model
    , Msg
    , decoder
    , init
    , subscriptions
    , update
    )

import Browser.Events
import Constants
import Dropbox
import DropboxAppState exposing (DecodeOutcome(..), DropboxAppState, PendingAction)
import Effect exposing (Effect)
import GridLayout2
import Json.Decode
import Json.Encode as E
import Ports
import Process
import RemoteData exposing (RemoteData(..))
import Route exposing (Route)
import Shared.Model exposing (Toast)
import Shared.Msg
import Task



-- FLAGS


type alias Flags =
    { initialAuthState : Maybe Dropbox.UserAuth
    , userAgent : String
    , redirectUri : String
    , windowSize : GridLayout2.WindowSize
    , buildVersion : String
    }


decoder : Json.Decode.Decoder Flags
decoder =
    Json.Decode.map5 Flags
        (Json.Decode.field "initialAuthState"
            (Json.Decode.oneOf
                [ Json.Decode.map Just Dropbox.decodeUserAuth
                , Json.Decode.succeed Nothing
                ]
            )
        )
        (Json.Decode.field "userAgent" Json.Decode.string)
        (Json.Decode.field "redirectUri" Json.Decode.string)
        (Json.Decode.field "windowSize" GridLayout2.windowSizeDecoder)
        (Json.Decode.field "buildVersion" Json.Decode.string)



-- INIT


type alias Model =
    Shared.Model.Model


layoutConfig : GridLayout2.LayoutConfig
layoutConfig =
    { mobileScreen =
        { minGridWidth = 360
        , maxGridWidth = Just 720
        , columnCount = 6
        , gutter = 16
        , margin = GridLayout2.SameAsGutter
        }
    , desktopScreen =
        { minGridWidth = 1024
        , maxGridWidth = Just 1440
        , columnCount = 12
        , gutter = 32
        , margin = GridLayout2.SameAsGutter
        }
    }


meaninglessDefaultModel : Shared.Model.Model
meaninglessDefaultModel =
    { layout = GridLayout2.init layoutConfig { width = 1024, height = 768 }
    , auth = Nothing
    , storageContents = NotAsked
    , userAgent = ""
    , redirectUri = ""
    , verifiedContents = Nothing
    , fileRevision = Nothing
    , inFlightActions = []
    , queuedActions = []
    , dropboxConflictRetryCount = 0
    , toasts = []
    , nextToastId = 0
    , reinitializeInFlight = False
    , buildVersion = ""
    }


init : Result Json.Decode.Error Flags -> Route () -> ( Model, Effect Msg )
init flagsResult _ =
    case flagsResult of
        Ok flags ->
            initReady flags

        Err _ ->
            ( meaninglessDefaultModel, Effect.none )


initReady : Flags -> ( Model, Effect Msg )
initReady flags =
    let
        model : Model
        model =
            { layout = GridLayout2.init layoutConfig flags.windowSize
            , auth = flags.initialAuthState
            , storageContents =
                case flags.initialAuthState of
                    Just _ ->
                        Loading

                    Nothing ->
                        NotAsked
            , userAgent = flags.userAgent
            , redirectUri = flags.redirectUri
            , verifiedContents = Nothing
            , fileRevision = Nothing
            , inFlightActions = []
            , queuedActions = []
            , dropboxConflictRetryCount = 0
            , toasts = []
            , nextToastId = 0
            , reinitializeInFlight = False
            , buildVersion = flags.buildVersion
            }

        downloadCmd : Effect Msg
        downloadCmd =
            case flags.initialAuthState of
                Just auth ->
                    startDownload auth

                Nothing ->
                    Effect.none
    in
    ( model, downloadCmd )



-- CONFIG


standardAuthRequest : Dropbox.AuthorizeRequest
standardAuthRequest =
    Constants.dropboxAuthRequest



-- UPDATE


type alias Msg =
    Shared.Msg.Msg


update : Route () -> Msg -> Model -> ( Model, Effect Msg )
update route msg model =
    case msg of
        Shared.Msg.GotNewWindowSize newWindowSize ->
            ( { model | layout = GridLayout2.update model.layout newWindowSize }, Effect.none )

        Shared.Msg.GotFileResponse response ->
            handleFileResponse route model response

        Shared.Msg.SaveRequested action ->
            handleSaveRequested model action

        Shared.Msg.GotSaveResponse result ->
            handleSaveResponse model result

        Shared.Msg.GotConflictDownloadResponse response ->
            handleConflictDownload model response

        Shared.Msg.ReinitializeState ->
            case model.auth of
                Just auth ->
                    let
                        emptyState : DropboxAppState
                        emptyState =
                            DropboxAppState.empty
                    in
                    ( { model
                        | storageContents = Success emptyState
                        , verifiedContents = Just emptyState
                        , inFlightActions = []
                        , queuedActions = []
                        , dropboxConflictRetryCount = 0
                        , reinitializeInFlight = True
                      }
                    , startUpload auth emptyState model.fileRevision
                    )

                Nothing ->
                    ( model, Effect.none )

        Shared.Msg.SignOut ->
            let
                authUrl : String
                authUrl =
                    Dropbox.authorizationUrl standardAuthRequest model.redirectUri
            in
            ( model
            , Effect.batch
                [ Effect.sendCmd Ports.clearAuth
                , Effect.loadExternalUrl authUrl
                ]
            )

        Shared.Msg.AddToast toastType message ->
            let
                toastId : Int
                toastId =
                    model.nextToastId

                toast : Toast
                toast =
                    { id = toastId, message = message, toastType = toastType }

                dismissCmd : Cmd Msg
                dismissCmd =
                    Process.sleep 5000
                        |> Task.perform (\_ -> Shared.Msg.DismissToast toastId)
            in
            ( { model
                | toasts = model.toasts ++ [ toast ]
                , nextToastId = toastId + 1
              }
            , Effect.sendCmd dismissCmd
            )

        Shared.Msg.DismissToast toastId ->
            ( { model | toasts = List.filter (\t -> t.id /= toastId) model.toasts }
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Route () -> Model -> Sub Msg
subscriptions _ _ =
    Browser.Events.onResize (\width height -> Shared.Msg.GotNewWindowSize { width = width, height = height })



-- ---------------------------------------------------------------------------
-- DROPBOX CONCURRENCY: optimistic updates, queue, conflict retry
-- ---------------------------------------------------------------------------


dropboxFilePath : String
dropboxFilePath =
    "/app-state.json"


downloadRequest : Dropbox.DownloadRequest
downloadRequest =
    Dropbox.DownloadRequest dropboxFilePath


uploadRequest : Dropbox.WriteMode -> String -> Dropbox.UploadRequest
uploadRequest mode content =
    { path = dropboxFilePath
    , mode = mode
    , autorename = False
    , clientModified = Nothing
    , mute = False
    , content = content
    }


writeMode : Maybe String -> Dropbox.WriteMode
writeMode maybeRev =
    case maybeRev of
        Just rev ->
            Dropbox.Update rev

        Nothing ->
            Dropbox.Overwrite


startDownload : Dropbox.UserAuth -> Effect Msg
startDownload auth =
    Effect.sendCmd
        (Dropbox.download auth downloadRequest
            |> Task.mapError downloadErrorToString
            |> Task.attempt Shared.Msg.GotFileResponse
        )


startUpload : Dropbox.UserAuth -> DropboxAppState -> Maybe String -> Effect Msg
startUpload auth appState maybeRev =
    let
        content : String
        content =
            appState |> DropboxAppState.encoder |> E.encode 0
    in
    Effect.sendCmd
        (content
            |> uploadRequest (writeMode maybeRev)
            |> Dropbox.upload auth
            |> Task.attempt Shared.Msg.GotSaveResponse
        )


clearActions : Model -> Model
clearActions model =
    { model
        | inFlightActions = []
        , queuedActions = []
        , dropboxConflictRetryCount = 0
        , reinitializeInFlight = False
        , storageContents =
            case model.verifiedContents of
                Just verified ->
                    Success verified

                Nothing ->
                    model.storageContents
    }


initWithEmpty : Model -> Dropbox.UserAuth -> ( Model, Effect Msg )
initWithEmpty model auth =
    let
        emptyState : DropboxAppState
        emptyState =
            DropboxAppState.empty
    in
    ( { model
        | storageContents = Success emptyState
        , verifiedContents = Just emptyState
        , fileRevision = Nothing
      }
    , startUpload auth emptyState Nothing
    )


handleFileResponse : Route () -> Model -> Result String Dropbox.DownloadResponse -> ( Model, Effect Msg )
handleFileResponse _ model response =
    case response of
        Ok downloadResponse ->
            case Json.Decode.decodeString DropboxAppState.decodeAppState downloadResponse.content of
                Ok (Decoded appState) ->
                    ( { model
                        | storageContents = Success appState
                        , verifiedContents = Just appState
                        , fileRevision = Just downloadResponse.rev
                      }
                    , Effect.none
                    )

                Ok VersionTooHigh ->
                    let
                        versionMsg : String
                        versionMsg =
                            "Please refresh the page to use the latest version"
                    in
                    ( { model | storageContents = Failure versionMsg, fileRevision = Just downloadResponse.rev }
                    , Effect.addErrorToast versionMsg
                    )

                Ok (Invalid msg) ->
                    ( { model | storageContents = Failure msg, fileRevision = Just downloadResponse.rev }
                    , Effect.addErrorToast msg
                    )

                Err _ ->
                    ( { model | storageContents = Failure "State data is invalid", fileRevision = Just downloadResponse.rev }
                    , Effect.addErrorToast "State data is invalid"
                    )

        Err errMsg ->
            if isAuthErrorString errMsg then
                triggerReAuth model

            else
                -- File not found, path error, etc. — auto-create with empty state
                case model.auth of
                    Just auth ->
                        initWithEmpty model auth

                    Nothing ->
                        ( { model | storageContents = Failure errMsg }, Effect.none )


handleSaveRequested : Model -> PendingAction -> ( Model, Effect Msg )
handleSaveRequested model action =
    case ( model.auth, model.verifiedContents, model.storageContents ) of
        ( Just auth, Just verified, Success optimistic ) ->
            let
                newOptimistic : DropboxAppState
                newOptimistic =
                    DropboxAppState.applyAction action optimistic
            in
            if List.isEmpty model.inFlightActions then
                let
                    uploadState : DropboxAppState
                    uploadState =
                        DropboxAppState.applyAction action verified
                in
                ( { model
                    | storageContents = Success newOptimistic
                    , inFlightActions = [ action ]
                    , dropboxConflictRetryCount = 0
                  }
                , startUpload auth uploadState model.fileRevision
                )

            else
                ( { model
                    | storageContents = Success newOptimistic
                    , queuedActions = model.queuedActions ++ [ action ]
                  }
                , Effect.none
                )

        _ ->
            ( model, Effect.none )


handleSaveResponse : Model -> Result Dropbox.UploadError Dropbox.FileMetadata -> ( Model, Effect Msg )
handleSaveResponse model result =
    case result of
        Ok fileMetadata ->
            let
                newVerified : DropboxAppState
                newVerified =
                    case model.verifiedContents of
                        Just v ->
                            List.foldl DropboxAppState.applyAction v model.inFlightActions

                        Nothing ->
                            DropboxAppState.empty

                newModel : Model
                newModel =
                    { model
                        | fileRevision = Just fileMetadata.rev
                        , verifiedContents = Just newVerified
                        , inFlightActions = []
                        , dropboxConflictRetryCount = 0
                    }
            in
            case ( model.auth, model.queuedActions ) of
                ( Just auth, next :: rest ) ->
                    let
                        uploadState : DropboxAppState
                        uploadState =
                            DropboxAppState.applyAction next newVerified
                    in
                    ( { newModel
                        | inFlightActions = [ next ]
                        , queuedActions = rest
                      }
                    , startUpload auth uploadState (Just fileMetadata.rev)
                    )

                _ ->
                    if model.reinitializeInFlight then
                        ( { newModel | reinitializeInFlight = False }
                        , Effect.addSuccessToast "App state reinitialized"
                        )

                    else
                        ( newModel, Effect.none )

        Err (Dropbox.Path { reason }) ->
            case reason of
                Dropbox.Conflict _ ->
                    if model.dropboxConflictRetryCount < 3 then
                        case model.auth of
                            Just auth ->
                                ( { model
                                    | dropboxConflictRetryCount = model.dropboxConflictRetryCount + 1
                                  }
                                , Effect.sendCmd
                                    (Dropbox.download auth downloadRequest
                                        |> Task.mapError downloadErrorToString
                                        |> Task.attempt Shared.Msg.GotConflictDownloadResponse
                                    )
                                )

                            Nothing ->
                                ( clearActions model, Effect.none )

                    else
                        ( clearActions model
                        , Effect.addErrorToast "Conflict: max retries exceeded"
                        )

                _ ->
                    ( clearActions model
                    , Effect.addErrorToast "Upload error"
                    )

        Err err ->
            if isAuthUploadError err then
                triggerReAuth model

            else
                ( clearActions model
                , Effect.addErrorToast (uploadErrorToString err)
                )


handleConflictDownload : Model -> Result String Dropbox.DownloadResponse -> ( Model, Effect Msg )
handleConflictDownload model response =
    case response of
        Ok downloadResponse ->
            case Json.Decode.decodeString DropboxAppState.decodeAppState downloadResponse.content of
                Ok (Decoded freshState) ->
                    case model.auth of
                        Just auth ->
                            let
                                allActions : List PendingAction
                                allActions =
                                    model.inFlightActions ++ model.queuedActions

                                uploadState : DropboxAppState
                                uploadState =
                                    List.foldl DropboxAppState.applyAction freshState model.inFlightActions

                                optimistic : DropboxAppState
                                optimistic =
                                    List.foldl DropboxAppState.applyAction freshState allActions
                            in
                            ( { model
                                | storageContents = Success optimistic
                                , verifiedContents = Just freshState
                                , fileRevision = Just downloadResponse.rev
                              }
                            , startUpload auth uploadState (Just downloadResponse.rev)
                            )

                        Nothing ->
                            ( { model
                                | storageContents = Success freshState
                                , verifiedContents = Just freshState
                                , fileRevision = Just downloadResponse.rev
                                , inFlightActions = []
                                , queuedActions = []
                              }
                            , Effect.none
                            )

                Ok VersionTooHigh ->
                    let
                        versionMsg : String
                        versionMsg =
                            "Please refresh the page to use the latest version"
                    in
                    ( clearActions model |> (\m -> { m | storageContents = Failure versionMsg })
                    , Effect.addErrorToast versionMsg
                    )

                Ok (Invalid msg) ->
                    ( clearActions model |> (\m -> { m | storageContents = Failure msg })
                    , Effect.addErrorToast msg
                    )

                Err _ ->
                    let
                        errMsg : String
                        errMsg =
                            "State data is invalid"
                    in
                    ( clearActions model |> (\m -> { m | storageContents = Failure errMsg })
                    , Effect.addErrorToast errMsg
                    )

        Err errMsg ->
            if isAuthErrorString errMsg then
                triggerReAuth model

            else
                ( clearActions model
                , Effect.addErrorToast ("Conflict re-download failed: " ++ errMsg)
                )



-- ERROR HELPERS


isAuthErrorTag : String -> Bool
isAuthErrorTag tag =
    tag == "expired_access_token" || tag == "invalid_access_token"


isAuthErrorString : String -> Bool
isAuthErrorString errMsg =
    String.contains "expired_access_token" errMsg
        || String.contains "invalid_access_token" errMsg


isAuthUploadError : Dropbox.UploadError -> Bool
isAuthUploadError error =
    case error of
        Dropbox.OtherUploadError tag _ ->
            isAuthErrorTag tag

        _ ->
            False


triggerReAuth : Model -> ( Model, Effect Msg )
triggerReAuth model =
    let
        authUrl : String
        authUrl =
            Dropbox.authorizationUrl standardAuthRequest model.redirectUri
    in
    ( model
    , Effect.batch
        [ Effect.sendCmd Ports.clearAuth
        , Effect.loadExternalUrl authUrl
        ]
    )


downloadErrorToString : Dropbox.DownloadError -> String
downloadErrorToString error =
    case error of
        Dropbox.PathDownloadError Dropbox.NotFound ->
            "File not found"

        Dropbox.PathDownloadError Dropbox.NotFile ->
            "Not a file"

        Dropbox.PathDownloadError Dropbox.RestrictedContent ->
            "Restricted content"

        Dropbox.PathDownloadError _ ->
            "Path error"

        Dropbox.OtherDownloadError tag _ ->
            "Dropbox error: " ++ tag

        Dropbox.OtherDownloadFailure _ ->
            "Network error"


uploadErrorToString : Dropbox.UploadError -> String
uploadErrorToString error =
    case error of
        Dropbox.Path _ ->
            "Path write error"

        Dropbox.OtherUploadError tag _ ->
            "Dropbox error: " ++ tag

        Dropbox.OtherUploadFailure _ ->
            "Network error"
