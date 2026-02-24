module AppStateTest exposing (suite)

import AppState exposing (DecodeOutcome(..), AppState, PendingAction(..))
import Expect
import Json.Decode as D
import Json.Encode as E
import Test exposing (Test, describe, test)
import Time


testStateV1 : String
testStateV1 =
    """
    {
      "chat": [
        {
          "userAgent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
          "message": "Hello, world!",
          "timestamp": 1700000000000
        }
      ],
      "stateVersion": 1
    }
    """


expectedChat : List AppState.ChatRecord
expectedChat =
    [ { userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
      , message = "Hello, world!"
      , timestamp = Time.millisToPosix 1700000000000
      }
    ]


expectDecoded : (AppState -> Expect.Expectation) -> Result D.Error DecodeOutcome -> Expect.Expectation
expectDecoded check result =
    case result of
        Ok (Decoded state) ->
            check state

        Ok VersionTooHigh ->
            Expect.fail "Expected Ok (Decoded _), got VersionTooHigh"

        Ok (Invalid msg) ->
            Expect.fail ("Expected Ok (Decoded _), got Invalid: " ++ msg)

        Err err ->
            Expect.fail ("Expected Ok (Decoded _), got Err: " ++ D.errorToString err)


testStateFutureVersion : String
testStateFutureVersion =
    """
    {
      "chat": [],
      "stateVersion": 99
    }
    """


testStateDamaged : String
testStateDamaged =
    """
    {
      "chat": "not a list",
      "stateVersion": 1
    }
    """


testStateInvalid : String
testStateInvalid =
    """
    { "garbage": true }
    """


suite : Test
suite =
    describe "AppState decoders"
        [ test "appStateDecoderV1 decodes valid state" <|
            \_ ->
                D.decodeString AppState.appStateDecoderV1 testStateV1
                    |> expectDecoded
                        (\s -> Expect.equal expectedChat s.chat)
        , test "decodeAppState returns Decoded for valid state" <|
            \_ ->
                D.decodeString AppState.decodeAppState testStateV1
                    |> expectDecoded
                        (\s -> Expect.equal expectedChat s.chat)
        , test "chat round-trip encode/decode" <|
            \_ ->
                let
                    original : AppState
                    original =
                        { chat =
                            [ { userAgent = "test-agent"
                              , message = "test message"
                              , timestamp = Time.millisToPosix 1000
                              }
                            ]
                        }

                    json : String
                    json =
                        AppState.encoder original |> E.encode 0
                in
                D.decodeString AppState.decodeAppState json
                    |> expectDecoded
                        (\s -> Expect.equal original.chat s.chat)
        , test "decodeAppState returns VersionTooHigh for future version" <|
            \_ ->
                D.decodeString AppState.decodeAppState testStateFutureVersion
                    |> Expect.equal (Ok VersionTooHigh)
        , test "decodeAppState returns Invalid for damaged state" <|
            \_ ->
                D.decodeString AppState.decodeAppState testStateDamaged
                    |> Expect.equal (Ok (Invalid "Damaged app state (version 1), consider reinitializing"))
        , test "decodeAppState fails for garbage JSON" <|
            \_ ->
                D.decodeString AppState.decodeAppState testStateInvalid
                    |> Expect.err
        , test "applyAction AddMessage prepends to chat" <|
            \_ ->
                let
                    record : AppState.ChatRecord
                    record =
                        { userAgent = "test"
                        , message = "hello"
                        , timestamp = Time.millisToPosix 1700000000000
                        }

                    result : AppState
                    result =
                        AppState.applyAction (AddMessage record) AppState.empty
                in
                Expect.equal [ record ] result.chat
        , test "applyAction AddMessage prepends multiple messages" <|
            \_ ->
                let
                    record1 : AppState.ChatRecord
                    record1 =
                        { userAgent = "test", message = "first", timestamp = Time.millisToPosix 1000 }

                    record2 : AppState.ChatRecord
                    record2 =
                        { userAgent = "test", message = "second", timestamp = Time.millisToPosix 2000 }

                    result : AppState
                    result =
                        AppState.empty
                            |> AppState.applyAction (AddMessage record1)
                            |> AppState.applyAction (AddMessage record2)
                in
                Expect.equal [ record2, record1 ] result.chat
        , test "decodeAppState v1 ignores extra fields" <|
            \_ ->
                let
                    stateWithExtra : String
                    stateWithExtra =
                        """
                        {
                          "chat": [],
                          "stateVersion": 1
                        }
                        """
                in
                D.decodeString AppState.decodeAppState stateWithExtra
                    |> expectDecoded
                        (\s -> Expect.equal [] s.chat)
        ]
