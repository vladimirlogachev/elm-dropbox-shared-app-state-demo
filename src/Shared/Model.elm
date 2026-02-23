module Shared.Model exposing (Model, Toast, ToastType(..))

import Dropbox
import DropboxAppState exposing (DropboxAppState, PendingAction)
import GridLayout2
import RemoteData exposing (RemoteData)


type ToastType
    = SuccessToast
    | ErrorToast


type alias Toast =
    { id : Int
    , message : String
    , toastType : ToastType
    }


type alias Model =
    { layout : GridLayout2.LayoutState
    , auth : Maybe Dropbox.UserAuth
    , storageContents : RemoteData String DropboxAppState
    , verifiedContents : Maybe DropboxAppState
    , userAgent : String
    , redirectUri : String
    , fileRevision : Maybe String
    , inFlightActions : List PendingAction
    , queuedActions : List PendingAction
    , dropboxConflictRetryCount : Int
    , toasts : List Toast
    , nextToastId : Int
    , reinitializeInFlight : Bool
    , buildVersion : String
    }
