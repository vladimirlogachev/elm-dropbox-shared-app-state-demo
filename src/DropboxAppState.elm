module DropboxAppState exposing
    ( ChatRecord
    , DecodeOutcome(..)
    , DropboxAppState
    , PendingAction(..)
    , applyAction
    , decodeAppState
    , dropboxAppStateDecoderV1
    , empty
    , encoder
    , listMessages
    )

import Json.Decode as D exposing (Decoder)
import Json.Encode as E
import Time exposing (Posix, millisToPosix, posixToMillis)


type alias DropboxAppState =
    { chat : List ChatRecord
    }


currentStateVersion : Int
currentStateVersion =
    1


empty : DropboxAppState
empty =
    { chat = [] }


encoder : DropboxAppState -> E.Value
encoder sc =
    E.object
        [ ( "chat", E.list chatRecordEncoder sc.chat )
        , ( "stateVersion", E.int currentStateVersion )
        ]


dropboxAppStateDecoderV1 : Decoder DecodeOutcome
dropboxAppStateDecoderV1 =
    D.oneOf
        [ D.map Decoded
            (D.map DropboxAppState
                (D.field "chat" (D.list chatRecordDecoder))
            )
        , D.succeed (Invalid "Damaged app state (version 1), consider reinitializing")
        ]


type DecodeOutcome
    = Decoded DropboxAppState
    | VersionTooHigh
    | Invalid String


decodeAppState : Decoder DecodeOutcome
decodeAppState =
    D.field "stateVersion" D.int
        |> D.andThen
            (\v ->
                case v of
                    1 ->
                        dropboxAppStateDecoderV1

                    -- add other versions here
                    _ ->
                        D.succeed VersionTooHigh
            )


type alias ChatRecord =
    { userAgent : String
    , message : String
    , timestamp : Posix
    }


chatRecordEncoder : ChatRecord -> E.Value
chatRecordEncoder r =
    E.object
        [ ( "userAgent", E.string r.userAgent )
        , ( "message", E.string r.message )
        , ( "timestamp", E.int (posixToMillis r.timestamp) )
        ]


chatRecordDecoder : Decoder ChatRecord
chatRecordDecoder =
    D.map3 ChatRecord
        (D.field "userAgent" D.string)
        (D.field "message" D.string)
        (D.field "timestamp" (D.map millisToPosix D.int))


type PendingAction
    = AddMessage ChatRecord


applyAction : PendingAction -> DropboxAppState -> DropboxAppState
applyAction action sc =
    case action of
        AddMessage record ->
            addMessage record sc


addMessage : ChatRecord -> DropboxAppState -> DropboxAppState
addMessage record sc =
    { sc | chat = record :: sc.chat }


listMessages : DropboxAppState -> List ChatRecord
listMessages sc =
    sc.chat
