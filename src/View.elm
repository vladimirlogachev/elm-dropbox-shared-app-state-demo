module View exposing
    ( View
    , fromString
    , map
    , none
    , toBrowserDocument
    )

import Browser
import Element
import Route exposing (Route)
import Shared.Model


type alias View msg =
    { title : String
    , attributes : List (Element.Attribute msg)
    , element : Element.Element msg
    }


toBrowserDocument :
    { shared : Shared.Model.Model
    , route : Route ()
    , view : View msg
    }
    -> Browser.Document msg
toBrowserDocument { view } =
    { title = view.title
    , body = [ Element.layout view.attributes view.element ]
    }


map : (msg1 -> msg2) -> View msg1 -> View msg2
map fn view =
    { title = view.title
    , attributes = List.map (Element.mapAttribute fn) view.attributes
    , element = Element.map fn view.element
    }


none : View msg
none =
    { title = ""
    , attributes = []
    , element = Element.none
    }


fromString : String -> View msg
fromString moduleName =
    { title = moduleName
    , attributes = []
    , element = Element.text moduleName
    }
