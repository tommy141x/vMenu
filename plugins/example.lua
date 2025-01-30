--[[
    vMenu Example Plugin with Dynamic Button Management
]]

-- Track dynamic button states
local dynamicButtons = {}
local buttonCounter = 0

ExamplePlugin = {
    name = "Example Plugin",
    version = "1.0.0",
    author = "TIMMYG",
    dependencies = {},
    mainSubMenu = { -- Optionally add a main submenu for your plugin
        id = "example_main",
        title = "Plugin Example",
        desc = "Menu demonstrations",
        position = 6
    },
    init = function()
        if not IsDuplicityVersion() then
            createDynamicButtonMenu()
            createInteractiveListMenu()
            createCheckboxShowcaseMenu()
        end
    end
}

function createDynamicButtonMenu()
    exports["vMenu"]:CreateMenu("dynamic_buttons", "Dynamic Button Management")
    exports["vMenu"]:AddSubmenuButton("example_main", "dynamic_buttons", "Dynamic Buttons",
        "Add/Remove buttons dynamically")

    -- Button to add new dynamic buttons
    exports["vMenu"]:AddButton("dynamic_buttons", "add_dynamic_button", "Add Dynamic Button",
        "Creates a new button with a unique identifier", function()
            buttonCounter = buttonCounter + 1
            local buttonId = "dynamic_button_" .. buttonCounter
            local buttonLabel = "Dynamic Button #" .. buttonCounter

            exports["vMenu"]:AddButton("dynamic_buttons", buttonId, buttonLabel, "A dynamically created button",
                function()
                    exports["vMenu"]:Notify("Dynamic Button #" .. buttonCounter .. " Pressed!", "success")
                end)

            -- Track the button for potential removal
            table.insert(dynamicButtons, { id = buttonId, label = buttonLabel })
            exports["vMenu"]:Notify("Added: " .. buttonLabel, "info")
        end)

    -- Button to remove last added dynamic button
    exports["vMenu"]:AddButton("dynamic_buttons", "remove_last_button", "Remove Last Button",
        "Removes the most recently added dynamic button", function()
            if #dynamicButtons > 0 then
                local lastButton = table.remove(dynamicButtons)
                exports["vMenu"]:RemoveItem("dynamic_buttons", lastButton.id)
                exports["vMenu"]:Notify("Removed: " .. lastButton.label, "success")
            else
                exports["vMenu"]:Notify("No dynamic buttons to remove", "error")
            end
        end)
end

function createCheckboxShowcaseMenu()
    exports["vMenu"]:CreateMenu("checkbox_showcase", "Checkbox Showcase")
    exports["vMenu"]:AddSubmenuButton("example_main", "checkbox_showcase", "Checkbox Options",
        "Demonstrate checkbox interactions")

    -- Performance mode checkbox
    exports["vMenu"]:AddCheckbox("checkbox_showcase", "performance_mode", "Performance Mode",
        "Toggle enhanced performance settings", false, function(isChecked)
            local notificationType = isChecked and "success" or "info"
            exports["vMenu"]:Notify("Performance Mode " .. (isChecked and "Enabled" or "Disabled"), notificationType)
        end)

    -- Stealth mode checkbox
    exports["vMenu"]:AddCheckbox("checkbox_showcase", "stealth_mode", "Stealth Mode",
        "Toggle reduced player visibility", false, function(isChecked)
            local notificationType = isChecked and "success" or "info"
            exports["vMenu"]:Notify("Stealth Mode " .. (isChecked and "Enabled" or "Disabled"), notificationType)
        end)
end

function createInteractiveListMenu()
    exports["vMenu"]:CreateMenu("interactive_list", "Interactive List Demo")
    exports["vMenu"]:AddSubmenuButton("example_main", "interactive_list", "Interactive List",
        "List with detailed interactions")

    local activities = json.encode({
        "Fishing",
        "Hunting",
        "Diving",
        "Skydiving",
        "Racing"
    })

    exports["vMenu"]:AddList("interactive_list", "activity_selection", "Select Activity",
        activities, 0, "Choose an activity to explore", function(oldIndex, newIndex, selectedOption, isSelected)
            if isSelected then
                -- User pressed Enter on the list item
                exports["vMenu"]:Notify("Selected Action: " .. selectedOption, "success")
                -- Simulate starting the activity
            else
                -- User just navigated the list
                exports["vMenu"]:Notify("Switched: " .. selectedOption, "info")
            end
        end)
end
