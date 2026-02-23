module Markdown exposing (preparedMarkdown)

import Color
import Element exposing (..)
import Element.Background
import Element.Border
import Element.Font as Font
import Element.Input
import Element.Region
import Html
import Html.Attributes
import Markdown.Block as Block exposing (ListItem(..), Task(..))
import Markdown.Html
import Markdown.Parser as Markdown
import Markdown.Renderer
import TextStyle



{- This module provides markdown support with presets for elm-ui, aware of our styles and of typographic conversion -}


elmUiRenderer : Markdown.Renderer.Renderer (Element msg)
elmUiRenderer =
    { heading = heading
    , paragraph =
        Element.paragraph
            [ Element.spacing 15 ]
    , thematicBreak = Element.none
    , text = text
    , strong = \content -> Element.paragraph [ Font.semiBold ] content
    , emphasis = \content -> Element.paragraph [ Font.italic ] content
    , strikethrough = \content -> Element.paragraph [ Font.strike ] content
    , codeSpan = code
    , link =
        \{ destination } body ->
            -- TODO: noopener noreferrer?
            Element.newTabLink
                [ Element.htmlAttribute (Html.Attributes.style "display" "inline-flex") ]
                { url = destination
                , label = Element.paragraph [ Font.color Color.primaryBlue ] body
                }
    , hardLineBreak = Html.br [] [] |> Element.html
    , image =
        \image ->
            case image.title of
                Just _ ->
                    Element.image [ Element.width Element.fill ] { src = image.src, description = image.alt }

                Nothing ->
                    Element.image [ Element.width Element.fill ] { src = image.src, description = image.alt }
    , blockQuote =
        \children ->
            Element.column
                [ Element.Border.widthEach { top = 0, right = 0, bottom = 0, left = 10 }
                , Element.padding 10
                , Element.Border.color Color.greyDimmed1
                , Element.Background.color Color.greyDimmed3
                ]
                children
    , unorderedList =
        -- Note: Make sure to test changes on mobile (watch out for the horizontal scroll)
        \items ->
            Element.column [ Element.spacing 15 ]
                (items
                    |> List.map
                        (\(ListItem task children) ->
                            Element.row
                                [ Element.alignTop, spacing 5 ]
                                [ case task of
                                    IncompleteTask ->
                                        Element.Input.defaultCheckbox False

                                    CompletedTask ->
                                        Element.Input.defaultCheckbox True

                                    NoTask ->
                                        Element.text "•"
                                , Element.text " "
                                , paragraph [] children
                                ]
                        )
                )
    , orderedList =
        \startingIndex items ->
            Element.column [ Element.spacing 15 ]
                (items
                    |> List.indexedMap
                        (\index itemBlocks ->
                            Element.row [ Element.spacing 5, Element.alignTop ]
                                [ Element.text (String.fromInt (index + startingIndex) ++ " ")
                                , Element.paragraph [] itemBlocks
                                ]
                        )
                )
    , codeBlock = codeBlock
    , html = Markdown.Html.oneOf []
    , table = Element.column []
    , tableHeader = Element.column []
    , tableBody = Element.column []
    , tableRow = Element.row []
    , tableHeaderCell =
        \_ children ->
            Element.paragraph [] children
    , tableCell =
        \_ children ->
            Element.paragraph [] children
    }


code : String -> Element msg
code snippet =
    Element.el
        [ Element.Background.color
            (Element.rgba 0 0 0 0.04)
        , Element.Border.rounded 2
        , Element.paddingXY 5 3
        , Font.family [ Font.typeface "JetBrains Mono", Font.monospace ]
        ]
        (Element.text snippet)


codeBlock : { body : String, language : Maybe String } -> Element msg
codeBlock details =
    Element.el [ Element.width Element.fill, Element.clip ]
        (Element.html
            (Html.pre
                [ Html.Attributes.style "white-space" "pre"
                , Html.Attributes.style "overflow-x" "auto"
                , Html.Attributes.style "margin" "0"
                , Html.Attributes.style "padding" "20px"
                , Html.Attributes.style "background-color" "rgba(0,0,0,0.03)"
                , Html.Attributes.style "font-family" "'JetBrains Mono', monospace"
                , Html.Attributes.style "font-size" "16px"
                , Html.Attributes.style "line-height" "1.6"
                , Html.Attributes.style "-webkit-text-size-adjust" "100%"
                ]
                [ Html.text details.body ]
            )
        )


heading : { level : Block.HeadingLevel, rawText : String, children : List (Element msg) } -> Element msg
heading { level, rawText, children } =
    Element.paragraph
        ((case level of
            Block.H1 ->
                TextStyle.header.attrs

            Block.H2 ->
                TextStyle.subheader.attrs

            _ ->
                TextStyle.contentBody
         )
            ++ [ Element.Region.heading (Block.headingLevelToInt level)
               , Element.htmlAttribute
                    (Html.Attributes.attribute "name" (rawTextToId rawText))
               , Element.htmlAttribute
                    (Html.Attributes.id (rawTextToId rawText))
               ]
        )
        children


rawTextToId : String -> String
rawTextToId rawText =
    rawText
        |> String.split " "
        |> String.join "-"
        |> String.toLower


preparedMarkdown : String -> Element msg
preparedMarkdown markdownInput =
    case
        markdownInput
            |> Markdown.parse
            |> Result.mapError (List.map Markdown.deadEndToString >> String.join "\n")
            |> Result.andThen (\ast -> Markdown.Renderer.render elmUiRenderer ast)
    of
        Ok rendered ->
            column [ width fill, spacing 20 ] rendered

        Err _ ->
            text "Failed to display the document"
