module Route.Path exposing (Path(..), fromString, fromUrl, href, toString)

import Html
import Html.Attributes
import Url exposing (Url)
import Url.Parser exposing ((</>))
import HashRouting


type Path
    = Home_
    | Chat
    | Help
    | Settings
    | Welcome
    | NotFound_


fromUrl : Url -> Path
fromUrl url =
    HashRouting.transformToHashUrl url
        |> Maybe.map .path
        |> Maybe.andThen fromString
        |> Maybe.withDefault NotFound_


fromString : String -> Maybe Path
fromString urlPath =
    let
        urlPathSegments : List String
        urlPathSegments =
            urlPath
                |> String.split "/"
                |> List.filter (String.trim >> String.isEmpty >> Basics.not)
    in
    case urlPathSegments of
        [] ->
            Just Home_

        "chat" :: [] ->
            Just Chat

        "help" :: [] ->
            Just Help

        "settings" :: [] ->
            Just Settings

        "welcome" :: [] ->
            Just Welcome

        _ ->
            Nothing


href : Path -> Html.Attribute msg
href path =
    Html.Attributes.href (toString path)


toString : Path -> String
toString path =
    let
        pieces : List String
        pieces =
            case path of
                Home_ ->
                    []

                Chat ->
                    [ "chat" ]

                Help ->
                    [ "help" ]

                Settings ->
                    [ "settings" ]

                Welcome ->
                    [ "welcome" ]

                NotFound_ ->
                    [ "404" ]
    in
    pieces
        |> String.join "/"
        |> String.append "#/"
