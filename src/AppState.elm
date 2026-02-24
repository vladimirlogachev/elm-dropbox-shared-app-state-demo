module AppState exposing
    ( AppState
    , ChatRecord
    , DecodeOutcome(..)
    , PendingAction(..)
    , appStateDecoderV1
    , applyAction
    , decodeAppState
    , empty
    , encoder
    , listMessages
    )

import Json.Decode as D exposing (Decoder)
import Json.Encode as E
import Time exposing (Posix, millisToPosix, posixToMillis)


type alias AppState =
    { chat : List ChatRecord
    }


currentStateVersion : Int
currentStateVersion =
    1


empty : AppState
empty =
    { chat = [] }


encoder : AppState -> E.Value
encoder sc =
    E.object
        [ ( "chat", E.list chatRecordEncoder sc.chat )
        , ( "stateVersion", E.int currentStateVersion )
        ]


appStateDecoderV1 : Decoder DecodeOutcome
appStateDecoderV1 =
    D.oneOf
        [ D.map Decoded
            (D.map AppState
                (D.field "chat" (D.list chatRecordDecoder))
            )
        , D.succeed (Invalid "Damaged app state (version 1), consider reinitializing")
        ]


type DecodeOutcome
    = Decoded AppState
    | VersionTooHigh
    | Invalid String


decodeAppState : Decoder DecodeOutcome
decodeAppState =
    D.field "stateVersion" D.int
        |> D.andThen
            (\v ->
                case v of
                    1 ->
                        appStateDecoderV1

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


applyAction : PendingAction -> AppState -> AppState
applyAction action sc =
    case action of
        AddMessage record ->
            addMessage record sc


addMessage : ChatRecord -> AppState -> AppState
addMessage record sc =
    { sc | chat = record :: sc.chat }


listMessages : AppState -> List ChatRecord
listMessages sc =
    sc.chat
