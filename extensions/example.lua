local isServer = IsDuplicityVersion()

function examplePlugin()
    if not isServer then
        exports["vMenu"]:CreateMenu("exampleid", "Example Plugin Menu")
        exports["vMenu"]:AddSubmenuButton("main", "exampleid", "Example Menu", "Example Menu Stuffs")
        exports["vMenu"]:AddButton("exampleid", "examplebuttonid", "Example Button", "Example Button Description",
            function()
                exports["vMenu"]:Notify("Example ~r~Button ~w~Pressed")
            end)
    end
    print("Example Plugin loaded.")
end
