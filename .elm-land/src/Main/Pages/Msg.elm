module Main.Pages.Msg exposing (Msg(..))

import Pages.Home_
import Pages.Chat
import Pages.Help
import Pages.Settings
import Pages.Welcome
import Pages.NotFound_


type Msg
    = Home_ Pages.Home_.Msg
    | Chat Pages.Chat.Msg
    | Help Pages.Help.Msg
    | Settings Pages.Settings.Msg
    | Welcome Pages.Welcome.Msg
    | NotFound_ Pages.NotFound_.Msg
