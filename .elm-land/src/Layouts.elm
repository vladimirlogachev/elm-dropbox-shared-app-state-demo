module Layouts exposing (..)

import Layouts.AppLayout
import Layouts.LandingLayout


type Layout msg
    = AppLayout Layouts.AppLayout.Props
    | LandingLayout Layouts.LandingLayout.Props


map : (msg1 -> msg2) -> Layout msg1 -> Layout msg2
map fn layout =
    case layout of
        AppLayout data ->
            AppLayout data

        LandingLayout data ->
            LandingLayout data
