module ReviewConfig exposing (config)

{-| Do not rename the ReviewConfig module or the config function, because
`elm-review` will look for these.

To add packages that contain rules, add them to this review project using

    `elm install author/packagename`

when inside the directory containing this file.

-}

import NoDebug.Log
import NoDebug.TodoOrToString
import NoExposingEverything
import NoImportingEverything
import NoMissingSubscriptionsCall
import NoMissingTypeAnnotation
import NoMissingTypeAnnotationInLetIn
import NoPrematureLetComputation
import NoRecursiveUpdate
import NoSimpleLetBody
import NoTestValuesInProductionCode
import NoUnoptimizedRecursion
import NoUnsafeDivision
import NoUnused.CustomTypeConstructorArgs
import NoUnused.CustomTypeConstructors
import NoUnused.Dependencies
import NoUnused.Exports
import NoUnused.Modules
import NoUnused.Parameters
import NoUnused.Patterns
import NoUnused.Variables
import NoUnusedPorts
import NoUselessSubscriptions
import Review.Rule as Rule exposing (Rule)
import Simplify


config : List Rule
config =
    [ NoDebug.Log.rule
    , NoDebug.TodoOrToString.rule
    , NoUnoptimizedRecursion.rule (NoUnoptimizedRecursion.optOutWithComment "IGNORE TCO")
        |> Rule.ignoreErrorsForFiles [ "src/Effect.elm" ]
    , Simplify.rule Simplify.defaults
        |> Rule.ignoreErrorsForFiles [ "src/DropboxAppState.elm" ]
    , NoTestValuesInProductionCode.rule
        (NoTestValuesInProductionCode.startsWith "stub_")
    , NoMissingSubscriptionsCall.rule
    , NoRecursiveUpdate.rule
    , NoUselessSubscriptions.rule
    , NoUnsafeDivision.rule
    , NoUnused.CustomTypeConstructors.rule []
    , NoUnused.CustomTypeConstructorArgs.rule
    , NoUnused.Dependencies.rule
    , NoUnused.Exports.rule |> Rule.ignoreErrorsForFiles [ "src/View.elm" ]
    , NoUnused.Modules.rule
    , NoUnused.Parameters.rule
    , NoUnused.Patterns.rule
    , NoUnused.Variables.rule
    , NoUnusedPorts.rule
    , NoImportingEverything.rule [ "Element", "GridLayout2" ]
    , NoExposingEverything.rule
    , NoMissingTypeAnnotation.rule
    , NoMissingTypeAnnotationInLetIn.rule
    , NoPrematureLetComputation.rule
    , NoSimpleLetBody.rule
    ]
        |> List.map (Rule.ignoreErrorsForDirectories [ ".elm-land/" ])
