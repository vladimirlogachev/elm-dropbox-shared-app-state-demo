module Constants exposing (dropboxAuthRequest)

import Dropbox


dropboxClientId : String
dropboxClientId =
    "0jnles280etnj3r"


dropboxAuthRequest : Dropbox.AuthorizeRequest
dropboxAuthRequest =
    { clientId = dropboxClientId
    , state = Nothing
    , requireRole = Nothing
    , forceReapprove = False
    , disableSignup = False
    , locale = Nothing
    , forceReauthentication = False
    }
