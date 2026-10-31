-- Exercise the running preview without touching system network preferences.
-- Run after launching dist/HallPass.app --args --demo; requires Accessibility access.
property returnKey : 36
property escapeKey : 53
property deleteKey : 51
property pollCount : 80
property pollDelay : 0.25

tell application "HallPass" to activate
tell application "System Events"
    tell process "HallPass"
        log "Open editor with CmdN"
        keystroke "n" using command down
        my waitForSheet()
        keystroke "10.0.0.0/8"
        key code returnKey
        my waitForNoSheet()

        log "Review additions with CmdS"
        log (entire contents of window 1)
        keystroke "s" using command down
        my waitForSheet()
        key code escapeKey
        my waitForNoSheet()

        -- Draft undo must be reached after the editor, not the closed field editor's undo.
        log "Undo and redo the draft"
        keystroke "z" using command down
        delay pollDelay
        keystroke "s" using command down
        delay pollDelay
        if exists sheet 1 of window 1 then error "Undo did not return the draft to its baseline."

        keystroke "z" using {command down, shift down}
        delay pollDelay
        keystroke "s" using command down
        my waitForSheet()
        key code escapeKey
        my waitForNoSheet()
        keystroke "z" using command down

        log "Cancel backup panels"
        keystroke "o" using command down
        my waitForSheet()
        key code escapeKey
        my waitForNoSheet()
        keystroke "e" using {command down, shift down}
        my waitForSheet()
        key code escapeKey
        my waitForNoSheet()

        -- Delete in search must edit the query, not the configuration.
        log "Edit the search query"
        keystroke "f" using command down
        keystroke "169.254"
        keystroke "a" using command down
        key code deleteKey
        key code escapeKey
        keystroke "s" using command down
        delay pollDelay
        if exists sheet 1 of window 1 then error "Search changed the draft."

        keystroke "i" using {command down, option down}
        delay pollDelay
        keystroke "i" using {command down, option down}
        log "Close and reopen the clean window"
        keystroke "w" using command down
        delay pollDelay
        if exists window 1 then error "The clean window did not close."
        keystroke "0" using command down
    end tell
end tell

repeat pollCount times
    tell application "System Events" to tell process "HallPass"
        if exists window 1 then return "Preview keyboard, undo/redo, review, file-panel cancellation, and window reopening passed."
    end tell
    delay pollDelay
end repeat
error "The configuration window did not reopen."

on waitForSheet()
    repeat pollCount times
        tell application "System Events" to tell process "HallPass"
            if exists sheet 1 of window 1 then return
        end tell
        delay pollDelay
    end repeat
    error "The expected sheet did not open."
end waitForSheet

on waitForNoSheet()
    repeat pollCount times
        tell application "System Events" to tell process "HallPass"
            if not (exists sheet 1 of window 1) then
                delay pollDelay
                return
            end if
        end tell
        delay pollDelay
    end repeat
    error "The sheet did not close."
end waitForNoSheet
