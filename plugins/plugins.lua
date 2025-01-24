--[[
░█▀▀█ ░█─── ░█─░█ ░█▀▀█ ▀█▀ ░█▄─░█ ░█▀▀▀█
░█▄▄█ ░█─── ░█─░█ ░█─▄▄ ░█─ ░█░█░█ ─▀▀▀▄▄
░█─── ░█▄▄█ ─▀▄▄▀ ░█▄▄█ ▄█▄ ░█──▀█ ░█▄▄▄█

Configuration file for vMenu plugins
]]

local enabledPlugins = { examplePlugin } -- Add your plugins init functions here

-- Reconstruction of the main menu, if you want to add custom main submenus in a custom order, you can do it here
local useReconstruction = true -- If you want to reconstruct the main menu, set this to true
local constructMainMenu = function()
    exports["vMenu"]:ClearMenu("main")
    exports["vMenu"]:AddSubmenuButton("main", "onlineplayers", "Online Players", "All currently connected players.")
    exports["vMenu"]:AddSubmenuButton("main", "bannedplayers", "Banned Players",
        "View and manage all banned players in this menu.")

    -- Uncomment the following to add a Roleplay submenu which you can add to later in a plugin.
    -- exports["vMenu"]:CreateMenu("roleplay", "Roleplay Related Options")
    -- exports["vMenu"]:AddSubmenuButton("main", "roleplay", "~g~Roleplay Related Options", "Open this submenu for roleplay-related subcategories.")

    exports["vMenu"]:AddSubmenuButton("main", "player", "Player Related Options",
        "Open this submenu for player related subcategories.")
    exports["vMenu"]:AddSubmenuButton("main", "vehicle", "Vehicle Related Options",
        "Open this submenu for vehicle related subcategories.")
    exports["vMenu"]:AddSubmenuButton("main", "world", "World Related Options",
        "Open this submenu for world related subcategories.")
    exports["vMenu"]:AddSubmenuButton("main", "voicechat", "Voice Chat Settings", "Change Voice Chat options here.")
    exports["vMenu"]:AddSubmenuButton("main", "recording", "Recording Options", "In-game recording options.")
    exports["vMenu"]:AddSubmenuButton("main", "miscsettings", "Misc Settings",
        "Miscellaneous vMenu options/settings can be configured here.")
    exports["vMenu"]:AddSubmenuButton("main", "about", "About vMenu", "Information about vMenu.")
end
























-- IMPORTANT: Do not modify anything below this line unless you know what you're doing.
local isServer = IsDuplicityVersion()
vMenuExtReady = false -- A global variable to check if the extensions API is ready
initvMenuExt = false
CreateThread(function()
    if initvMenuExt then return end
    initvMenuExt = true
    if isServer then
        vMenuExtReady = true
        init()
        return
    end

    while not exports.vMenu:CheckMenu("main") do
        Wait(500) -- Wait for 500ms before trying again
    end
    vMenuExtReady = true
    init()
end)

function init()
    print("[vMenu] Extensions API is ready!")
    if not isServer and useReconstruction then
        constructMainMenu()
    end
    for _, plugin in ipairs(enabledPlugins) do
        plugin()
    end
end
