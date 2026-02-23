module Auth exposing (User, onPageLoad, viewCustomPage)

import Auth.Action
import Constants
import Dropbox
import Route exposing (Route)
import Shared
import View exposing (View)


type alias User =
    {}


onPageLoad : Shared.Model -> Route () -> Auth.Action.Action User
onPageLoad shared _ =
    case shared.auth of
        Just _ ->
            Auth.Action.loadPageWithUser {}

        Nothing ->
            Auth.Action.loadExternalUrl
                (Dropbox.authorizationUrl Constants.dropboxAuthRequest shared.redirectUri)


viewCustomPage : Shared.Model -> Route () -> View Never
viewCustomPage _ _ =
    View.fromString "Loading..."
