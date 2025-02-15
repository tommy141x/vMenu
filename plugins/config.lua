--[[
    ░█▀▀█ ░█─── ░█─░█ ░█▀▀█ ▀█▀ ░█▄─░█ ░█▀▀▀█
    ░█▄▄█ ░█─── ░█─░█ ░█─▄▄ ░█─ ░█░█░█ ─▀▀▀▄▄
    ░█─── ░█▄▄█ ─▀▄▄▀ ░█▄▄█ ▄█▄ ░█──▀█ ░█▄▄▄█

    Configuration file for vMenu plugins
]]

-- List of plugins to load
local plugins = {
    "ExamplePlugin",
    "CinematicCamPlugin",
}

-- Default menu items, you can remove or re-order these as you like.
local defaultMenuItems = {
    { id = "onlineplayers", name = "Online Players",          desc = "All currently connected players." },
    {id = "bannedplayers", name = "Banned Players", desc = "View and manage all banned players in this menu."},
    { id = "player",        name = "Player Related Options",  desc = "Open this submenu for player related subcategories." },
    { id = "vehicle",       name = "Vehicle Related Options", desc = "Open this submenu for vehicle related subcategories." },
    { id = "world",         name = "World Related Options",   desc = "Open this submenu for world related subcategories." },
    { id = "voicechat",     name = "Voice Chat Settings",     desc = "Change Voice Chat options here." },
    {id = "recording", name = "Recording Options", desc = "In-game recording options."},
    { id = "miscsettings",  name = "Misc Settings",           desc = "Miscellaneous vMenu options/settings can be configured here." },
    {id = "about", name = "About vMenu", desc = "Information about vMenu."}
}




























-- IMPORTANT: Do not modify anything below this line unless you know what you're doing.
local isServer = IsDuplicityVersion()
vMenuExtReady = false
initvMenuExt = false
local loadedPlugins = {}
local pluginsInProgress = {}

-- Function to determine the relative position of menu items
local function compareMenuItems(a, b)
    local aPos = a.position or 999
    local bPos = b.position or 999

    if (a.isPlugin and b.isPlugin) or (a.defaultIndex and b.defaultIndex) then
        if aPos == bPos then
            local aName = a.isPlugin and a.pluginName or a.name
            local bName = b.isPlugin and b.pluginName or b.name
            return aName < bName
        end
        return aPos < bPos
    end

    if a.isPlugin and b.defaultIndex then
        return aPos <= b.defaultIndex
    elseif a.defaultIndex and b.isPlugin then
        return a.defaultIndex < bPos
    end

    return aPos < bPos
end

-- Validate plugin structure
local function validatePlugin(plugin)
    if type(plugin) ~= "table" then
        return false, "Plugin must be a table"
    end

    if type(plugin.name) ~= "string" then
        return false, "Plugin must have a name"
    end

    if plugin.dependencies and type(plugin.dependencies) ~= "table" then
        return false, "Dependencies must be a table"
    end

    if type(plugin.init) ~= "function" then
        return false, "Plugin must have an init function"
    end

    return true
end

-- Read and validate all plugins
local function readAndValidatePlugins()
    local pluginData = {}

    for _, pluginName in ipairs(plugins) do
        local plugin = _G[pluginName]
        if not plugin then
            print(string.format("[vMenu] Error: Plugin '%s' not found in global scope", pluginName))
            return false
        end

        local isValid, error = validatePlugin(plugin)
        if not isValid then
            print(string.format("[vMenu] Error: Invalid plugin '%s': %s", pluginName, error))
            return false
        end

        -- Store plugin data for menu construction
        if plugin.mainSubMenu then
            table.insert(pluginData, {
                id = plugin.mainSubMenu.id,
                name = plugin.mainSubMenu.title,
                desc = plugin.mainSubMenu.desc,
                position = plugin.mainSubMenu.position or 999,
                isPlugin = true,
                pluginName = plugin.name
            })
            exports["vMenu"]:CreateMenu(plugin.mainSubMenu.id, plugin.mainSubMenu.title)
        end
    end

    return pluginData
end

-- Reconstruction of the main menu
local function constructMainMenu(pluginData)
    -- Clear existing menu
    exports["vMenu"]:ClearMenu("main")

    -- Collect all menu items including plugin-defined ones
    local menuItems = {}

    -- Add plugin-defined submenus first, marking them as plugins
    for _, data in ipairs(pluginData) do
        table.insert(menuItems, data)
    end

    -- Add default menu items with their index for position reference
    for i, item in ipairs(defaultMenuItems) do
        table.insert(menuItems, {
            id = item.id,
            name = item.name,
            desc = item.desc,
            position = i,
            defaultIndex = i
        })
    end

    -- Sort menu items using our custom comparison function
    table.sort(menuItems, compareMenuItems)

    -- Add all menu items in sorted order
    for _, item in ipairs(menuItems) do
        if item.onOpen then
            exports["vMenu"]:AddSubmenuButton("main", item.id, item.name, item.desc, item.onOpen)
        else
            exports["vMenu"]:AddSubmenuButton("main", item.id, item.name, item.desc)
        end
    end
end

-- Load a plugin and its dependencies
local function loadPlugin(pluginName)
    -- Skip if already loaded
    if loadedPlugins[pluginName] then
        return true
    end

    -- Get plugin definition from global scope
    local plugin = _G[pluginName]
    if not plugin then
        print(string.format("[vMenu] Error: Plugin '%s' not found in global scope", pluginName))
        return false
    end

    -- Validate plugin structure
    local isValid, error = validatePlugin(plugin)
    if not isValid then
        print(string.format("[vMenu] Error: Invalid plugin '%s': %s", pluginName, error))
        return false
    end

    -- Check for circular dependencies
    if pluginsInProgress[pluginName] then
        print(string.format("[vMenu] Error: Circular dependency detected for plugin '%s'", plugin.name))
        return false
    end

    pluginsInProgress[pluginName] = true

    -- Load dependencies first
    if plugin.dependencies then
        for _, depName in ipairs(plugin.dependencies) do
            if not _G[depName] then
                print(string.format("[vMenu] Error: Dependency '%s' for '%s' not found", depName, plugin.name))
                pluginsInProgress[pluginName] = nil
                return false
            end

            local success = loadPlugin(depName)
            if not success then
                print(string.format("[vMenu] Error: Failed to load dependency '%s' for '%s'", depName, plugin.name))
                pluginsInProgress[pluginName] = nil
                return false
            end
        end
    end

    -- Initialize the plugin
    plugin.alive = true
    local success, error = pcall(plugin.init, plugin)
    if not success then
        print(string.format("[vMenu] Error initializing plugin '%s': %s", plugin.name, tostring(error)))
        pluginsInProgress[pluginName] = nil
        return false
    end

    -- Store the full plugin definition in loadedPlugins
    loadedPlugins[pluginName] = plugin

    -- Log successful load
    local version = plugin.version and (" v" .. plugin.version) or ""
    local author = plugin.author and (" by " .. plugin.author) or ""
    print(string.format("[vMenu] Loaded %s%s%s", plugin.name, version, author))

    pluginsInProgress[pluginName] = nil
    return true
end

-- Load all plugins and set vMenuExtReady when complete
local function loadAllPlugins()
    -- Load all plugins in order
    for _, pluginName in ipairs(plugins) do
        local success = loadPlugin(pluginName)
        if not success then
            print(string.format("[vMenu] Failed to load plugin: %s",
                (_G[pluginName] and _G[pluginName].name) or pluginName))
        end
    end
    vMenuExtReady = true
end

-- Plugin system initialization thread
CreateThread(function()
    if initvMenuExt then return end
    initvMenuExt = true

    if isServer then
        loadAllPlugins()
        return
    else
        -- Wait for vMenu to be ready
        while not exports.vMenu:CheckMenu("main") do
            Wait(500)
        end

        -- Read and validate plugins first
        local pluginData = readAndValidatePlugins()
        if not pluginData then
            print("[vMenu] Error: Failed to read and validate plugins")
            return
        end

        -- Construct the main menu after reading plugin data
        constructMainMenu(pluginData)

        -- Now that main menu is ready, load all plugins
        loadAllPlugins()
    end
end)

-- Plugin system status check
function pluginsReady()
    return vMenuExtReady
end

-- Wait for plugins to be ready
function waitForPlugins(cb)
    CreateThread(function()
        while not pluginsReady() do
            Wait(500)
        end
        cb()
    end)
end
