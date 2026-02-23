module TextStyle exposing (body, contentBody, header, secondary, subheader)

import Color
import Element exposing (..)
import Element.Font as Font


body : List (Attribute msg)
body =
    [ Font.size 16, Font.regular, Font.family [ Font.typeface "Inter", Font.sansSerif ] ]


secondary : List (Attribute msg)
secondary =
    [ Font.size 14, Font.regular, Font.color Color.greySecondary, Font.family [ Font.typeface "Inter", Font.sansSerif ] ]


contentBody : List (Attribute msg)
contentBody =
    [ Font.size 20, Font.regular, Font.family [ Font.typeface "Inter", Font.sansSerif ] ]


subheaderDesktop : List (Attribute msg)
subheaderDesktop =
    [ Font.size 26, Font.medium, Font.family [ Font.typeface "Inter", Font.sansSerif ] ]


header : { attrs : List (Attribute msg) }
header =
    { attrs = [ Font.size 32, Font.semiBold, Font.family [ Font.typeface "Inter", Font.sansSerif ] ]
    }


subheader : { attrs : List (Attribute msg) }
subheader =
    { attrs = subheaderDesktop
    }
