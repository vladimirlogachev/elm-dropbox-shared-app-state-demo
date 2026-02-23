module Color exposing
    ( amber
    , green
    , greyDimmed1
    , greyDimmed3
    , greyLight
    , greyMuted
    , greySecondary
    , primaryBlue
    , red
    , silver
    , white
    )

import Element exposing (..)


white : Color
white =
    rgb255 255 255 255


primaryBlue : Color
primaryBlue =
    rgb255 0 87 255


greyDimmed1 : Color
greyDimmed1 =
    rgb255 140 140 140


greyDimmed3 : Color
greyDimmed3 =
    rgb255 242 242 242


silver : Color
silver =
    rgb255 0xBD 0xC3 0xC7


green : Color
green =
    rgb255 0x27 0xAE 0x60


greyLight : Color
greyLight =
    rgb255 0xE5 0xE7 0xE9


greyMuted : Color
greyMuted =
    rgb255 0x95 0xA5 0xA6


red : Color
red =
    rgb255 0xE7 0x4C 0x3C


amber : Color
amber =
    rgb255 0xF3 0x9C 0x12


greySecondary : Color
greySecondary =
    rgb255 0x7F 0x8C 0x8D
