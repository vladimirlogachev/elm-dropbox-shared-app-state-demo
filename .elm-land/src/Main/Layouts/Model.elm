module Main.Layouts.Model exposing (..)

import Layouts.AppLayout
import Layouts.LandingLayout


type Model
    = AppLayout { appLayout : Layouts.AppLayout.Model }
    | LandingLayout { landingLayout : Layouts.LandingLayout.Model }
