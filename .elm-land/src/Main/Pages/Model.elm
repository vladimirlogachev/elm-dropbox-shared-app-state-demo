module Main.Pages.Model exposing (Model(..))

import Pages.Home_
import Pages.Chat
import Pages.Help
import Pages.Settings
import Pages.Welcome
import Pages.NotFound_
import View exposing (View)


type Model
    = Home_ Pages.Home_.Model
    | Chat Pages.Chat.Model
    | Help Pages.Help.Model
    | Settings Pages.Settings.Model
    | Welcome Pages.Welcome.Model
    | NotFound_ Pages.NotFound_.Model
    | Redirecting_
    | Loading_
