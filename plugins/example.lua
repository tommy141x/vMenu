local isServer = IsDuplicityVersion()

function examplePlugin()
    if not isServer then
        -- Create the menu
        exports["vMenu"]:CreateMenu("exampleid", "Example Plugin Menu")

        -- Add a submenu button to navigate to this menu
        exports["vMenu"]:AddSubmenuButton("main", "exampleid", "Example Menu", "Example Menu Stuffs")

        -- Add a button with a callback
        exports["vMenu"]:AddButton("exampleid", "examplebuttonid", "Example Button", "Example Button Description",
            function()
                exports["vMenu"]:Notify("Example ~r~Button ~w~Pressed")
            end)

        -- Add a list with a callback
        local doors = json.encode({ "Front Left", "Front Right", "Rear Left", "Rear Right" })
        exports["vMenu"]:AddList("exampleid", "removeDoorList", "Remove Door", doors, 0, "Select a door to remove.",
            function(oldIndex, selectedIndex, selectedOption)
                exports["vMenu"]:Notify("Selected Door Index: ~g~" .. selectedIndex)
                exports["vMenu"]:Notify("Selected Door: ~g~" .. selectedOption)
                -- Additional logic for handling door removal
            end)

        -- Add a checkbox with a callback
        exports["vMenu"]:AddCheckbox("exampleid", "enableBlip", "Add Blip For Personal Vehicle",
            "Toggle blip for your personal vehicle.", false, function(isChecked)
                if isChecked then
                    exports["vMenu"]:Notify("Blip ~g~enabled~w~ for your personal vehicle.")
                    -- Additional logic for enabling the blip
                else
                    exports["vMenu"]:Notify("Blip ~r~disabled~w~ for your personal vehicle.")
                    -- Additional logic for disabling the blip
                end
            end)
    end

    print("[vMenu] Example Plugin Loaded")
end
