-- Read-only check of a CI-owned recovery fixture; never applies system settings.
property returnKey : 36
property pollCount : 80
property pollDelay : 0.25
property sheetSettleDelay : 1

tell application "HallPass" to activate
my requireText("Entwurf wiederhergestellt")
my requireText("legacy-invalid-value")

tell application "System Events" to tell process "HallPass"
    keystroke "w" using command down
    my waitForSheet()
    key code returnKey
    my waitForNoSheet()
    keystroke "q" using command down
    my waitForSheet()
    key code returnKey
    my waitForNoSheet()
    if not (exists window 1) then error "Canceling quit did not retain the recovered draft."
end tell
return "Recovery, unchanged legacy values, close cancellation, and quit cancellation passed."

on requireText(expectedText)
    repeat pollCount times
        tell application "System Events" to tell process "HallPass"
            if exists window 1 then
                repeat with uiElement in (get entire contents of window 1)
                    if (get role of uiElement) is "AXStaticText" then
                        if (get value of uiElement) is expectedText then return
                    end if
                end repeat
            end if
        end tell
        delay pollDelay
    end repeat
    error "The recovery view is missing: " & expectedText
end requireText

on waitForSheet()
    repeat pollCount times
        try
            tell application "System Events" to tell process "HallPass"
                if exists sheet 1 of window 1 then
                    delay sheetSettleDelay
                    return
                end if
            end tell
        end try
        delay pollDelay
    end repeat
    error "The expected unsaved-change sheet did not open."
end waitForSheet

on waitForNoSheet()
    repeat pollCount times
        try
            tell application "System Events" to tell process "HallPass"
                if not (exists sheet 1 of window 1) then
                    delay sheetSettleDelay
                    return
                end if
            end tell
        end try
        delay pollDelay
    end repeat
    error "Cancel did not dismiss the unsaved-change sheet."
end waitForNoSheet
