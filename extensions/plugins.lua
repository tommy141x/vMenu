-- Configuration
local enabledPlugins = { examplePlugin }
vMenuExtReady = false

-- Don't touch anything below this line
initvMenuExt = false
local isServer = IsDuplicityVersion()
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
    for _, plugin in ipairs(enabledPlugins) do
        plugin()
    end
end
