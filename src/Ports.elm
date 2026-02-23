port module Ports exposing (clearAuth)

import Json.Encode as E


port storeAuthState : E.Value -> Cmd msg


clearAuth : Cmd msg
clearAuth =
    storeAuthState E.null
