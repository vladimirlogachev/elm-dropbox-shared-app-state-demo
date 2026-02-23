module Shared.Msg exposing (Msg(..))

import Dropbox
import DropboxAppState exposing (PendingAction)
import GridLayout2
import Shared.Model exposing (ToastType)


type Msg
    = GotNewWindowSize GridLayout2.WindowSize
    | GotFileResponse (Result String Dropbox.DownloadResponse)
    | SaveRequested PendingAction
    | GotSaveResponse (Result Dropbox.UploadError Dropbox.FileMetadata)
    | GotConflictDownloadResponse (Result String Dropbox.DownloadResponse)
    | ReinitializeState
    | SignOut
    | AddToast ToastType String
    | DismissToast Int
