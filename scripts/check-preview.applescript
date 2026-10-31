-- Exercise the running preview without touching system network preferences.
-- Run after launching dist/HallPass.app --args --demo; requires Accessibility access.
property returnKey : 36
property escapeKey : 53
property deleteKey : 51
property tabKey : 48
property pollCount : 80
property pollDelay : 0.25
property sheetSettleDelay : 1

tell application "HallPass" to activate
my requirePreview()
set backupFolder to POSIX path of (path to temporary items)
set backupName to "HallPass-UI-" & (do shell script "/usr/bin/uuidgen") & ".json"
set backupFile to backupFolder & backupName
log "Check table mouse selection before any focus transitions"
my clickRange(1)
tell application "System Events"
    tell process "HallPass"
        log "Open editor with CmdN"
        keystroke "n" using command down
        my waitForSheet()
        keystroke "10.0.0.0/8"
        delay pollDelay
        set editorContents to get entire contents of sheet 1 of window 1
        set addressField to missing value
        repeat with uiElement in editorContents
            if (get role of uiElement) is "AXTextField" then
                set addressField to uiElement
                exit repeat
            end if
        end repeat
        if addressField is missing value then error "The address field is missing."
        log "Undo and redo native text input"
        keystroke "z" using command down
        delay pollDelay
        if (get value of addressField) is not "" then error "Text undo did not clear the input."
        keystroke "z" using {command down, shift down}
        delay pollDelay
        if (get value of addressField) is not "10.0.0.0/8" then error "Text redo did not restore the input."
        key code tabKey
        key code tabKey using shift down
        delay pollDelay
        if not (get focused of addressField) then error "Tab navigation did not return to the address field."
        key code returnKey
        my waitForNoSheet()

        log "Review additions with CmdS"
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
        my waitForSearchFocus()
        keystroke "169.254"
        keystroke "a" using command down
        key code deleteKey
        key code escapeKey
        keystroke "s" using command down
        delay pollDelay
        if exists sheet 1 of window 1 then error "Search changed the draft."

        log "Select, copy, remove, and edit table rows"
        log "Click the first network row"
        my clickRange(1)
        keystroke "a" using command down
        keystroke "c" using command down
        delay pollDelay
        my assertCopiedRanges()
        key code deleteKey
        delay pollDelay
        if my numberOfRanges() is not 0 then error "Delete did not remove the selected ranges."
        keystroke "z" using command down
        delay pollDelay
        if my numberOfRanges() is not 2 then error "Undo did not restore the selected ranges."
        my clickRange(1)
        key code returnKey using command down
        my waitForSheet()
        keystroke "a" using command down
        keystroke "192.0.2.7/32"
        key code returnKey
        my waitForNoSheet()
        keystroke "s" using command down
        my waitForSheet()
        my requireSheetText("192.0.2.7/32")
        my requireSheetText("169.254.0.0/16")
        key code escapeKey
        my waitForNoSheet()
        keystroke "z" using command down
        delay pollDelay

        log "Export and import a real JSON backup"
        keystroke "e" using {command down, shift down}
        my waitForSheet()
        keystroke "g" using {command down, shift down}
        delay sheetSettleDelay
        keystroke backupFolder
        key code returnKey
        delay sheetSettleDelay
        set saveControls to get entire contents of sheet 1 of window 1
        set nameField to missing value
        repeat with uiElement in saveControls
            if (get role of uiElement) is "AXTextField" then
                if (get value of uiElement) starts with "HallPass-Backup" then
                    set nameField to uiElement
                    exit repeat
                end if
            end if
        end repeat
        if nameField is missing value then error "The backup name field is missing."
        click nameField
        keystroke "a" using command down
        keystroke backupName
        key code returnKey
        my waitForNoSheet()
        my requireBackupFile(backupFile)
        my chooseMenuCommand("Alle Freigaben entfernen…")
        my waitForSheet()
        my pressSheetButton("Zum Entfernen vormerken")
        my waitForNoSheet()
        keystroke "o" using command down
        my waitForSheet()
        keystroke "g" using {command down, shift down}
        delay sheetSettleDelay
        keystroke backupFile
        key code returnKey
        delay sheetSettleDelay
        key code returnKey
        my waitForNoSheet()
        if my numberOfRanges() is not 2 then error "Backup round-trip did not restore both ranges."
        my removeBackupFixture(backupFile)

        log "Apply preview changes and reload sample data"
        keystroke "n" using command down
        my waitForSheet()
        keystroke "fe80::/10"
        key code returnKey
        my waitForNoSheet()
        keystroke "s" using command down
        my waitForSheet()
        key code returnKey
        my waitForNoSheet()
        keystroke "l" using command down
        delay sheetSettleDelay
        if my numberOfRanges() is not 2 then error "Reload did not restore the sample configuration."

        log "Resize and enter fullscreen"
        set size of window 1 to {720, 480}
        delay sheetSettleDelay
        set size of window 1 to {980, 640}
        keystroke "f" using {command down, control down}
        my waitForFullScreen()
        keystroke "f" using {command down, control down}
        my waitForWindowed()

        my clickRange(1)
        keystroke "i" using {command down, option down}
        delay sheetSettleDelay
        keystroke "i" using {command down, option down}
        delay sheetSettleDelay
        log "Close and reopen the clean window"
        keystroke "w" using command down
        delay pollDelay
        if exists window 1 then error "The clean window did not close."
        keystroke "0" using command down
        my waitForWindow()
        keystroke "w" using command down
        delay sheetSettleDelay
    end tell
    tell process "Dock" to click UI element "HallPass" of list 1
end tell

my waitForWindow()
tell application "System Events" to tell process "HallPass"
    my clickRange(1)
    keystroke "i" using {command down, option down}
end tell
delay sheetSettleDelay
return "Preview editing, focus, undo, selection, backup round-trip, apply, resizing, fullscreen, inspector, and reopening passed."

on requirePreview()
    tell application "System Events" to tell process "HallPass"
        repeat with uiElement in (get entire contents of window 1)
            if (get role of uiElement) is "AXStaticText" then
                if (get value of uiElement) is "Vorschau" then return
            end if
        end repeat
    end tell
    error "Launch a fresh HallPass instance with --demo before this check."
end requirePreview

on networkTable()
    repeat pollCount times
        try
            tell application "System Events" to tell process "HallPass"
                repeat with uiElement in (get entire contents of window 1)
                    if (get role of uiElement) is in {"AXOutline", "AXTable"} then
                        try
                            if (count columns of uiElement) is 3 then return uiElement
                        end try
                    end if
                end repeat
            end tell
        end try
        delay pollDelay
    end repeat
    error "The network table is missing."
end networkTable

on numberOfRanges()
    set rangeTable to my networkTable()
    tell application "System Events"
        return count rows of rangeTable
    end tell
end numberOfRanges

on clickRange(rowIndex)
    set rangeTable to my networkTable()
    tell application "System Events" to tell process "HallPass"
        set frontmost to true
        set targetRow to get row rowIndex of rangeTable
        log (get role of targetRow)
        set rowPosition to get position of targetRow
        set rowSize to get size of targetRow
        log rowPosition
        log rowSize
        set clickX to (item 1 of rowPosition) + (item 1 of rowSize) div 2
        set clickY to (item 2 of rowPosition) + (item 2 of rowSize) div 2
        log {clickX, clickY}
        my postMouseClick(clickX, clickY)
        delay pollDelay
        if not (get selected of targetRow) then error "The mouse click did not select the network row."
    end tell
    delay pollDelay
end clickRange

on postMouseClick(clickX, clickY)
    set probe to "import CoreGraphics; import Darwin; guard CGPreflightPostEventAccess(), let source = CGEventSource(stateID: .hidSystemState) else { print(\"Mouse event posting is not authorized\"); exit(1) }; let point = CGPoint(x: " & clickX & ", y: " & clickY & "); guard let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left) else { exit(1) }; down.setIntegerValueField(.mouseEventClickState, value: 1); down.post(tap: .cghidEventTap); usleep(100000); guard let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else { exit(1) }; up.setIntegerValueField(.mouseEventClickState, value: 1); up.post(tap: .cghidEventTap); usleep(100000)"
    do shell script "/usr/bin/xcrun swift -e " & quoted form of probe
end postMouseClick

on assertCopiedRanges()
    set probe to "import AppKit; let board = NSPasteboard.general; if let text = board.string(forType: .string) { print(text) } else { print(\"Clipboard has no text: \\(String(describing: board.types))\"); exit(1) }"
    set copiedText to do shell script "/usr/bin/xcrun swift -e " & quoted form of probe
    if paragraphs of copiedText is not {"169.254.0.0/16", "192.168.1.0/24"} then error "Copy did not include both selected ranges."
end assertCopiedRanges

on requireBackupFile(filePath)
    do shell script "/usr/bin/test -s " & quoted form of filePath
end requireBackupFile

on removeBackupFixture(filePath)
    do shell script "/bin/rm -f " & quoted form of filePath
end removeBackupFixture

on chooseMenuCommand(commandName)
    tell application "System Events" to tell process "HallPass"
        repeat with menuItem in menu bar items of menu bar 1
            if exists menu item commandName of menu 1 of menuItem then
                click menuItem
                click menu item commandName of menu 1 of menuItem
                return
            end if
        end repeat
    end tell
    error "The menu command is missing: " & commandName
end chooseMenuCommand

on pressSheetButton(buttonName)
    tell application "System Events" to tell process "HallPass"
        repeat with uiElement in (get entire contents of sheet 1 of window 1)
            if (get role of uiElement) is "AXButton" then
                if (get name of uiElement) is buttonName or (get description of uiElement) is buttonName then
                    click uiElement
                    return
                end if
            end if
        end repeat
    end tell
    error "The sheet button is missing: " & buttonName
end pressSheetButton

on requireSheetText(expectedText)
    tell application "System Events" to tell process "HallPass"
        repeat with uiElement in (get entire contents of sheet 1 of window 1)
            if (get role of uiElement) is "AXStaticText" then
                if (get value of uiElement) is expectedText then return
            end if
        end repeat
    end tell
    error "The review is missing: " & expectedText
end requireSheetText

on waitForWindow()
    repeat pollCount times
        tell application "System Events" to tell process "HallPass"
            if exists window 1 then
                delay sheetSettleDelay
                return
            end if
        end tell
        delay pollDelay
    end repeat
    error "The configuration window did not reopen."
end waitForWindow

on waitForFullScreen()
    repeat pollCount times
        tell application "System Events" to tell process "HallPass"
            if exists window 1 then
                if (get value of attribute "AXFullScreen" of window 1) then
                    delay sheetSettleDelay
                    return
                end if
            end if
        end tell
        delay pollDelay
    end repeat
    error "The window did not enter fullscreen."
end waitForFullScreen

on waitForWindowed()
    repeat pollCount times
        tell application "System Events" to tell process "HallPass"
            if exists window 1 then
                if not (get value of attribute "AXFullScreen" of window 1) then
                    delay sheetSettleDelay
                    return
                end if
            end if
        end tell
        delay pollDelay
    end repeat
    error "The window did not leave fullscreen."
end waitForWindowed

on waitForSheet()
    repeat pollCount times
        -- AppKit replaces accessibility objects during sheet transitions.
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
    error "The expected sheet did not open."
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
    error "The sheet did not close."
end waitForNoSheet

on waitForSearchFocus()
    repeat pollCount times
        try
            tell application "System Events" to tell process "HallPass"
                set focusedControl to get value of attribute "AXFocusedUIElement"
                if (get role of focusedControl) is "AXTextField" then
                    if (get subrole of focusedControl) is "AXSearchField" then return
                end if
            end tell
        end try
        delay pollDelay
    end repeat
    error "Search did not receive keyboard focus."
end waitForSearchFocus
