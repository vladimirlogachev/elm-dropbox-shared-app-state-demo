module Main.Layouts.Msg exposing (..)

import Layouts.AppLayout
import Layouts.LandingLayout


type Msg
    = AppLayout Layouts.AppLayout.Msg
    | LandingLayout Layouts.LandingLayout.Msg
