module Utils exposing (parseDevice)


parseDevice : String -> String
parseDevice ua =
    let
        lower : String
        lower =
            String.toLower ua
    in
    if String.contains "iphone" lower then
        "iPhone / iOS"

    else if String.contains "macintosh" lower || String.contains "mac os" lower then
        "Mac / macOS"

    else if String.contains "android" lower then
        "Android"

    else if String.contains "windows" lower then
        "Windows"

    else
        "Other"
