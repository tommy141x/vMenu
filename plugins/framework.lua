-- Characters Plugin for vMenu
-- Add "FrameworkPlugin" to the "plugins" table in the vMenu config file to enable this plugin.
-- This plugin requires the resource "u5_sqlite" from https://github.com/AdrianCeku/u5_sqlite
-- Configure the jobs, genders, and ethnicities below:

local Config = {
    Jobs = {
        {
            name = "Civilian",
            type = "civ",
            acePerm = "",
        },
        {
                name = "LSPD",
                type = "police",
                acePerm = "",
            },
            {
                    name = "SAHP",
                    type = "police",
                    acePerm = "",
                },
            {
                    name = "BCSO",
                    type = "police",
                    acePerm = "",
                },
                {
                    name = "SAFR",
                    type = "medical",
                    acePerm = "",
                },
    },
    -- job should still just be set to the job name as a lowercase string
    -- but now when getCharacter is called from client or server it should return the job type
    Genders = { "Male", "Female" },
    Ethnicities = { "Caucasian", "African American", "Hispanic", "Asian", "Middle Eastern", "Indian", "Native American", "Pacific Islander", "Other" }
}




FrameworkPlugin = {
    name = "Framework Plugin",
    version = "1.0.0",
    author = "TIMMYG",
    mainSubMenu = {
        id = "roleplay",
        title = "Roleplay Related Options",
        desc = "Open this submenu for roleplay-related subcategories.",
        onOpen = function()
            exports["vMenu"]:populateRoleplayMenu(false)
        end,
        position = 2 -- Should be the second submenu button in the main menu
    },
    dependencies = {},
    init = function()

    local function getJobType(jobName)
        -- Convert job name to lowercase for case-insensitive comparison
        jobName = string.lower(jobName)
        for _, jobData in ipairs(Config.Jobs) do
            if string.lower(jobData.name) == jobName then
                return jobData.type
            end
        end
        return "civ" -- Default type if not found
    end

        if IsDuplicityVersion() then
            local db = exports["u5_sqlite"]
            local globalState = {
                allCharacters = {},
                allVehicles = {}
            }

            -- Function to broadcast state updates to all clients
            local function broadcastStateUpdate()
                -- Fetch fresh data
                globalState.allCharacters = db:select("characters", { "*" }, {}, true) or {}
                globalState.allVehicles = db:select("vehicles", { "*" }, {}, true) or {}

                -- Add jobType for each character
                for _, character in ipairs(globalState.allCharacters) do
                    character.jobType = getJobType(character.job)
                end

                -- Broadcast to all clients
                TriggerClientEvent("framework:globalState:sync", -1, globalState)
            end

            local function getPlayerLicense(playerSrc)
                for _, v in pairs(GetPlayerIdentifiers(playerSrc)) do
                    if string.match(v, "license:") then
                        return v
                    end
                end
                return nil
            end

            local function getSafeCharacters(license)
                local charactersResult = db:select("characters", { "*" }, { license = license }) or {}
                local defaultCharacterResult = db:select("characters", { "*" }, { license = license, isDefault = 1 })

                local characters = #charactersResult > 0 and charactersResult or {}
                local defaultCharacter = defaultCharacterResult and defaultCharacterResult[1] or nil

                if not defaultCharacter and #characters > 0 then
                    defaultCharacter = characters[1]
                end
                return characters, defaultCharacter
            end

            local function getSafeVehicles(license)
                local vehiclesResult = db:select("vehicles", { "*" }, { license = license }) or {}
                return vehiclesResult
            end

            -- Database Setup
            -- db:executeRaw("DROP TABLE IF EXISTS vehicles")
            db:executeRaw(
                "CREATE TABLE IF NOT EXISTS characters (id INTEGER PRIMARY KEY AUTOINCREMENT, license TEXT, name TEXT, dob TEXT, gender TEXT, ethnicity TEXT, job TEXT, isDefault INTEGER, driversLicense TEXT, weaponsLicense TEXT)")
            db:executeRaw(
                "CREATE TABLE IF NOT EXISTS vehicles (id INTEGER PRIMARY KEY AUTOINCREMENT, license TEXT, characterId INTEGER, vin TEXT, plate TEXT, make TEXT, model TEXT, type TEXT, primaryColor TEXT, secondaryColor TEXT, isStolen INTEGER)")

            -- Event triggered when a player requests to fetch their characters and vehicles
            RegisterNetEvent("framework:characters:fetch")
            AddEventHandler("framework:characters:fetch", function()
                local playerSrc = source
                local license = getPlayerLicense(playerSrc)
                if not license then
                    TriggerClientEvent("framework:characters:receive", playerSrc, {}, nil)
                    return
                end

                -- Fetch characters and default character for the player's license
                local characters, defaultCharacter = getSafeCharacters(license)
                -- Fetch vehicles for the player's license from the database
                local vehicles = getSafeVehicles(license)

                -- Send characters and default character to the client
                TriggerClientEvent("framework:characters:receive", playerSrc, characters, defaultCharacter)
                -- Send vehicles to the client
                TriggerClientEvent("framework:vehicles:receive", playerSrc, vehicles)
            end)

            -- Event triggered when a player requests to delete a vehicle
            RegisterNetEvent("framework:vehicles:delete")
            AddEventHandler("framework:vehicles:delete", function(vehicleId)
                local playerSrc = source
                local license = getPlayerLicense(playerSrc)
                if not license then return end

                -- Delete the specified vehicle from the database
                db:delete("vehicles", { id = vehicleId, license = license })
                -- Fetch and send updated list of vehicles to the client
                local vehicles = getSafeVehicles(license)
                TriggerClientEvent("framework:vehicles:receive", playerSrc, vehicles)
                broadcastStateUpdate()
            end)

            -- Event triggered when a player registers or updates a vehicle
            RegisterNetEvent("framework:characters:registerVehicle")
            AddEventHandler("framework:characters:registerVehicle", function(vehicleData)
                local playerSrc = source
                local license = getPlayerLicense(playerSrc)
                if not license then return end

                -- Remove any whitespace from the vehicle plate
                vehicleData.plate = vehicleData.plate:gsub("%s+", "")

                -- Check if the plate is already in use by another vehicle
                local plateCheckResult = db:select("vehicles", { "*" }, { plate = vehicleData.plate })
                if plateCheckResult and #plateCheckResult > 0 then
                    for _, existingVehicle in ipairs(plateCheckResult) do
                        if existingVehicle.vin ~= vehicleData.vin then
                            TriggerClientEvent("framework:vMenu:Notify", playerSrc,
                                "The plate is already registered to another vehicle!", "error")
                            return
                        end
                    end
                end

                -- Check for an existing vehicle with the same VIN
                local vinResult = db:select("vehicles", { "*" }, { vin = vehicleData.vin })
                local existingVehicle = vinResult and vinResult[1] or nil

                if existingVehicle then
                    -- Update the existing vehicle record
                    db:update("vehicles", vehicleData, { id = existingVehicle.id, license = license })
                    TriggerClientEvent("framework:vMenu:Notify", playerSrc, "Vehicle updated!", "success")
                else
                    -- Insert a new vehicle record
                    vehicleData.license = license
                    db:insert("vehicles", vehicleData)
                    TriggerClientEvent("framework:vMenu:Notify", playerSrc, "Vehicle registered!", "success")
                end

                local vehicles = getSafeVehicles(license)
                TriggerClientEvent("framework:vehicles:receive", playerSrc, vehicles)
                broadcastStateUpdate()
            end)

            -- Event triggered when a player saves their character data
            RegisterNetEvent("framework:characters:save")
            AddEventHandler("framework:characters:save", function(characterData)
                local playerSrc = source
                local license = getPlayerLicense(playerSrc)
                if not license then return end

                -- Check for an existing character with the same name and update or notify accordingly
                local result = db:select("characters", { "*" }, { name = characterData.name, license = license })
                local existingCharacter = result and result[1] or nil
                if existingCharacter and (not characterData.id or existingCharacter.id ~= characterData.id) then
                    TriggerClientEvent("framework:vMenu:Notify", playerSrc, "A character with this name already exists!",
                        "error")
                    return
                end

                -- Normalize the job field to lowercase
                characterData.job = string.lower(characterData.job)

                -- Save or update the character based on whether an ID is provided
                if characterData.id then
                    db:update("characters", characterData, { id = characterData.id, license = license })
                else
                    characterData.license = license
                    db:insert("characters", characterData)
                end

                local characters, defaultCharacter = getSafeCharacters(license)
                TriggerClientEvent("framework:characters:receive", playerSrc, characters, defaultCharacter)
                TriggerClientEvent("framework:vMenu:Notify", playerSrc, "Character updated!", "success")

                -- Fetch and send updated list of vehicles to the client
                local vehicles = getSafeVehicles(license)
                TriggerClientEvent("framework:vehicles:receive", playerSrc, vehicles)
                broadcastStateUpdate()
            end)

            -- Event triggered when a player deletes their character
            RegisterNetEvent("framework:characters:delete")
            AddEventHandler("framework:characters:delete", function(characterId)
                local playerSrc = source
                local license = getPlayerLicense(playerSrc)
                if not license then return end

                -- Delete the specified character and associated vehicles from the database
                db:delete("characters", { id = characterId, license = license })
                db:delete("vehicles", { characterId = characterId, license = license })
                local characters, defaultCharacter = getSafeCharacters(license)
                TriggerClientEvent("framework:characters:receive", playerSrc, characters, defaultCharacter)

                -- Fetch and send updated list of vehicles to the client
                local vehicles = getSafeVehicles(license)
                TriggerClientEvent("framework:vehicles:receive", playerSrc, vehicles)
                broadcastStateUpdate()
            end)

            -- Event triggered when a player sets their default character
            RegisterNetEvent("framework:characters:setDefault")
            AddEventHandler("framework:characters:setDefault", function(characterId)
                local playerSrc = source
                local license = getPlayerLicense(playerSrc)
                if not license then return end

                -- Reset the isDefault flag for all characters of the player and set the specified character as default
                db:update("characters", { isDefault = 0 }, { license = license })
                db:update("characters", { isDefault = 1 }, { id = characterId, license = license })
                local characters, defaultCharacter = getSafeCharacters(license)
                TriggerClientEvent("framework:characters:receive", playerSrc, characters, defaultCharacter)
            end)

            exports("getCharacter", function(identifier, idType)
                if not idType then
                    idType = "source"
                end
                if idType == "license" then
                    local characters, defaultCharacter = getSafeCharacters(identifier)
                    if defaultCharacter then
                        defaultCharacter.jobType = getJobType(defaultCharacter.job)
                    end
                    return defaultCharacter
                elseif idType == "id" then
                    local result = db:select("characters", { "*" }, { id = identifier })
                    if result and #result > 0 then
                        result[1].jobType = getJobType(result[1].job)
                        return result[1]
                    end
                else
                    local license = getPlayerLicense(identifier)
                    if not license then return nil end
                    local characters, defaultCharacter = getSafeCharacters(license)
                    if defaultCharacter then
                        defaultCharacter.jobType = getJobType(defaultCharacter.job)
                    end
                    return defaultCharacter
                end
            end)

            -- Export functions to retrieve vehicles and characters by plate or player source
            exports("getVehicle", function(plate)
                local result = db:select("vehicles", { "*" }, { plate = plate })
                if result and #result > 0 then
                    return result[1]
                end
            end)

            exports("getVehicles", function(identifier, idType)
                if not idType then
                    idType = "source"
                end
                if idType == "license" then
                    local result = db:select("vehicles", { "*" }, { license = identifier })
                    return result or {}
                elseif idType == "id" then
                    local result = db:select("vehicles", { "*" }, { characterId = identifier })
                    return result or {}
                else
                local license = getPlayerLicense(identifier)
                if not license then return nil end
                local result = db:select("vehicles", { "*" }, { license = license })
                return result or {}
                end
            end)

            exports("getAllVehicles", function()
                allVehicles = db:select("vehicles", { "*" }, {}, true)
                return allVehicles
            end)

            exports("getAllCharacters", function()
                allCharacters = db:select("characters", { "*" }, {}, true)
                -- Add jobType for each character
                for _, character in ipairs(allCharacters) do
                    character.jobType = getJobType(character.job)
                end
                return allCharacters
            end)

            exports("getOnlineCharacters", function()
                local result = db:select("characters", { "*" }, { isDefault = 1 })
                for _, character in pairs(result) do
                    character.jobType = getJobType(character.job)
                    for _, player in ipairs(GetPlayers()) do
                        local license = getPlayerLicense(player)
                        if license == character.license then
                            return character
                        end
                    end
                end
            end)
        else
            local allCharacters = {}
            local allVehicles = {}
            local curChar = {}
            local vehicles = {}

            -- Register sync event handler
            RegisterNetEvent("framework:globalState:sync")
            AddEventHandler("framework:globalState:sync", function(state)
                allCharacters = state.allCharacters
                allVehicles = state.allVehicles
            end)

            Citizen.CreateThread(function()
                TriggerServerEvent("framework:globalState:request")
            end)

            function initRoleplayMenus()
                exports["vMenu"]:CreateMenu("characters_menu", "Characters")
                exports["vMenu"]:CreateMenu("vehicles_menu", "Registered Vehicles")
                exports["vMenu"]:CreateMenu("edit_vehicle_menu", "Edit Vehicle")
                local roleplayMenuInit = false
                exports("populateRoleplayMenu", function(forceUpdate)
                    if not roleplayMenuInit or forceUpdate or (curChar and curChar.job ~= (exports["vMenu"]:getCharacter() or {}).job) then
                        exports["vMenu"]:ClearMenu("roleplay")
                        exports["vMenu"]:AddSubmenuButton("roleplay", "characters_menu", "Characters",
                            "Manage your characters")
                        TriggerEvent("framework:populateRoleplayMenu")
                        roleplayMenuInit = true
                    end
                end)
                exports["vMenu"]:AddSubmenuButton("vehicle", "vehicles_menu", "Registered Vehicles",
                    "Manage your vehicles",
                    function()
                        populateRegisteredVehiclesMenu()
                    end)
                exports["vMenu"]:CreateMenu("edit_character_menu", "Edit Character")

                TriggerServerEvent("framework:characters:fetch")

                RegisterNetEvent("framework:vMenu:Notify")
                AddEventHandler("framework:vMenu:Notify", function(message, type)
                    exports["vMenu"]:Notify(message, type)
                end)

                RegisterNetEvent("framework:characters:receive")
                AddEventHandler("framework:characters:receive", function(receivedCharacters, defaultCharacter)
                    characters = receivedCharacters or {}
                    exports["vMenu"]:ClearMenu("characters_menu")
                    curChar = defaultCharacter

                    exports["vMenu"]:populateRoleplayMenu(true)

                    exports["vMenu"]:AddSubmenuButton("characters_menu", "edit_character_menu", "Create New Character",
                        "Create New Character", function()
                            populateEditCharacterMenu(nil)
                        end)

                    for _, character in pairs(characters) do
                        local prefix = curChar and curChar.id == character.id and "~g~" or ""
                        exports["vMenu"]:AddSubmenuButton("characters_menu", "edit_character_menu",
                            prefix .. character.name,
                            "Edit this character", function()
                                populateEditCharacterMenu(character)
                            end)
                    end
                end)

                RegisterNetEvent("framework:vehicles:receive")
                AddEventHandler("framework:vehicles:receive", function(vehs)
                    vehicles = vehs or {}
                    populateRegisteredVehiclesMenu()
                end)
            end

            function populateRegisteredVehiclesMenu()
                exports["vMenu"]:ClearMenu("vehicles_menu")
                exports["vMenu"]:AddButton("vehicles_menu", "register_vehicle", "~b~Register Current Vehicle",
                    "Registers your current vehicle to your current character.", function()
                        if not curChar then
                            exports["vMenu"]:Notify("You aren't playing as any character", "error")
                            return
                        end
                        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                        if vehicle == 0 then
                            exports["vMenu"]:Notify("You aren't in a vehicle", "error")
                            return
                        end

                        local details = GetVehicleDetails(vehicle)
                        local plate = GetVehicleNumberPlateText(vehicle)

                        local vehicleData = {
                            characterId = curChar.id,
                            plate = plate,
                            make = details.make,
                            model = details.model,
                            type = details.type,
                            primaryColor = details.primaryColor,
                            secondaryColor = details.secondaryColor,
                            isStolen = 0
                        }

                        vehicleData.vin = generateVIN(vehicleData)

                        TriggerServerEvent("framework:characters:registerVehicle", vehicleData)
                    end)

                for _, vehicle in pairs(vehicles) do
                    local owner = "Loading.."
                    for i, char in ipairs(characters) do
                        if vehicle and char.id == vehicle.characterId then
                            owner = char
                            break
                        end
                    end
                    -- check if we are in the vehicle by the plate
                    local curVeh = GetVehiclePedIsIn(PlayerPedId(), false)
                    local prfx = ""
                    if curVeh ~= 0 then
                        local curPlate = GetVehicleNumberPlateText(curVeh)
                        if curPlate == vehicle.plate then
                            prfx = "~g~"
                        end
                    end
                    exports["vMenu"]:AddSubmenuButton("vehicles_menu", "edit_vehicle_menu",
                        prfx .. vehicle.model .. " - " .. vehicle.plate, "Owned By " .. owner.name .. " ~b~(" ..
                        owner.job .. ")", function()
                            populateEditVehicleMenu(vehicle)
                        end)
                end
            end

            function populateEditVehicleMenu(vehicle)
                exports["vMenu"]:ClearMenu("edit_vehicle_menu")
                openEditVehicleMenu(vehicle)
            end

            function openEditVehicleMenu(vehicle)
                local tempVehicle = vehicle or
                    { id = nil, vin = "", plate = "", name = "", primaryColor = "", secondaryColor = "", isStolen = 0, characterId = nil }

                exports["vMenu"]:AddButton("edit_vehicle_menu", "plate_input", "~g~VIN: " .. tempVehicle.vin,
                    "Vehicle VIN", function()
                    end)

                exports["vMenu"]:AddButton("edit_vehicle_menu", "plate_input", "~g~Plate: " .. tempVehicle.plate,
                    "Vehicle Plate", function()
                        local newValue = getInput("Update Plate:", tempVehicle.plate)
                        if newValue and newValue:match("%S") then
                            tempVehicle.plate = newValue
                            populateEditVehicleMenu(tempVehicle)
                        end
                    end)

                exports["vMenu"]:AddButton("edit_vehicle_menu", "name_input", "~b~Manufacturer: " .. tempVehicle.make,
                    "Vehicle Name", function()
                        local newValue = getInput("Update Manufacturer:", tempVehicle.make)
                        if newValue and newValue:match("%S") then
                            tempVehicle.make = newValue
                            populateEditVehicleMenu(tempVehicle)
                        end
                    end)

                exports["vMenu"]:AddButton("edit_vehicle_menu", "name_input", "~b~Model: " .. tempVehicle.model,
                    "Vehicle Name", function()
                        local newValue = getInput("Update Model:", tempVehicle.model)
                        if newValue and newValue:match("%S") then
                            tempVehicle.model = newValue
                            populateEditVehicleMenu(tempVehicle)
                        end
                    end)

                exports["vMenu"]:AddButton("edit_vehicle_menu", "name_input",
                    "~b~Paint Color: " .. tempVehicle.primaryColor,
                    "Vehicle Name", function()
                        local newValue = getInput("Update Paint:", tempVehicle.primaryColor)
                        if newValue and newValue:match("%S") then
                            tempVehicle.primaryColor = newValue
                            populateEditVehicleMenu(tempVehicle)
                        end
                    end)


                local charactersList = {}
                local currentCharacterIndex = 0
                for i, char in ipairs(characters) do
                    table.insert(charactersList, char.name)
                    if vehicle and char.id == vehicle.characterId then
                        currentCharacterIndex = i - 1
                    end
                end

                exports["vMenu"]:AddList("edit_vehicle_menu", "character_selection", "~y~Associated Character",
                    json.encode(charactersList), currentCharacterIndex, "Select associated character",
                    function(_, _, selectedOption, isSelected)
                        for _, char in ipairs(characters) do
                            if char.name == selectedOption then
                                tempVehicle.characterId = char.id
                                break
                            end
                        end
                    end)

                local stolenIndex = tempVehicle.isStolen == 1 and 1 or 0
                exports["vMenu"]:AddList("edit_vehicle_menu", "stolen_status", "~r~Stolen Status",
                    json.encode({ "Not Stolen", "Stolen" }), stolenIndex, "Vehicle Stolen Status",
                    function(_, _, selectedOption, isSelected)
                        tempVehicle.isStolen = selectedOption == "Stolen" and 1 or 0
                    end)

                exports["vMenu"]:AddButton("edit_vehicle_menu", "delete_vehicle", "~r~Delete Vehicle",
                    "Permanently delete this vehicle", function()
                        TriggerServerEvent("framework:vehicles:delete", vehicle.id)
                        exports["vMenu"]:Notify("Vehicle deleted!", "info")
                        exports["vMenu"]:OpenMenu("vehicles_menu")
                    end)

                exports["vMenu"]:AddButton("edit_vehicle_menu", "save_vehicle", "~g~Save Vehicle", "Save vehicle details",
                    function()
                        TriggerServerEvent("framework:characters:registerVehicle", tempVehicle)
                        exports["vMenu"]:OpenMenu("vehicles_menu")
                    end)
            end

            function populateEditCharacterMenu(character)
                exports["vMenu"]:ClearMenu("edit_character_menu")
                openEditCharacterMenu(character)
            end

            function openEditCharacterMenu(character)
                local tempCharacter = character or
                    {
                        id = nil,
                        name = "",
                        dob = "",
                        gender = Config.Genders[1],
                        ethnicity = Config.Ethnicities[1],
                        job = string.lower(Config.Jobs[1].name) -- Default to first job name in lowercase
                    }

                    local jobsList = {}
                        local jobIndex = 0

                        -- Create a list of jobs the player has permission to use
                        for i, jobData in ipairs(Config.Jobs) do
                            if jobData.acePerm == "" or IsAceAllowed(jobData.acePerm) then
                                table.insert(jobsList, jobData.name)
                                -- Find the current job index based on lowercase comparison
                                if string.lower(jobData.name) == tempCharacter.job then
                                    jobIndex = #jobsList - 1
                                end
                            end
                        end

                if character and character.id then
                    if not (curChar and curChar.id == character.id) then
                        exports["vMenu"]:AddButton("edit_character_menu", "set_default", "Set Current Character",
                            "Play as this character", function()
                                TriggerServerEvent("framework:characters:setDefault", character.id)
                                exports["vMenu"]:Notify("You are now playing as " .. character.name, "success")
                                exports["vMenu"]:OpenMenu("characters_menu")
                            end)
                    end
                end

                exports["vMenu"]:AddButton("edit_character_menu", "name_input", "~g~Name: " .. tempCharacter.name,
                    "Click to edit Name", function()
                        local newValue = getInput("Enter Name (First Last):", tempCharacter.name)
                        if newValue then
                            -- Trim leading and trailing spaces
                            newValue = newValue:gsub("^%s*(.-)%s*$", "%1")

                            -- Split the input into words
                            local words = {}
                            for word in newValue:gmatch("%S+") do
                                table.insert(words, word)
                            end

                            -- Validate the input
                            local valid = false
                            if #words >= 2 then
                                local word1Valid = #words[1] > 1
                                local word2Valid = #words[2] > 1
                                valid = word1Valid and word2Valid and #newValue <= 25
                            end

                            if valid then
                                tempCharacter.name = newValue
                                populateEditCharacterMenu(tempCharacter)
                            else
                                exports["vMenu"]:Notify("Invalid Name", "error")
                            end
                        end
                    end)

                exports["vMenu"]:AddButton("edit_character_menu", "dob_input", "~g~Date of Birth: " .. tempCharacter.dob,
                    "Click to edit DOB", function()
                        local newValue = getInput("Enter Date of Birth (MM/DD/YYYY):", tempCharacter.dob)
                        if newValue then
                            -- Validate date format (MM/DD/YYYY)
                            if newValue:match("^%d%d/%d%d/%d%d%d%d$") then
                                tempCharacter.dob = newValue
                                populateEditCharacterMenu(tempCharacter)
                            else
                                exports["vMenu"]:Notify("Format should be: MM/DD/YYYY", "error")
                            end
                        end
                    end)

                local driversLicenseStatuses = { "None", "Valid", "Suspended", "Revoked" }
                local driversLicenseIndex = 0
                for i, status in ipairs(driversLicenseStatuses) do
                    if status == tempCharacter.driversLicense then
                        driversLicenseIndex = i - 1
                        break
                    end
                end

                exports["vMenu"]:AddList("edit_character_menu", "drivers_license", "~b~Drivers License",
                    json.encode(driversLicenseStatuses), driversLicenseIndex, "Drivers License Status",
                    function(_, _, selectedOption, isSelected)
                        tempCharacter.driversLicense = selectedOption
                    end)

                local weaponsLicenseStatuses = { "None", "Valid", "Suspended", "Revoked" }
                local weaponsLicenseIndex = 0
                for i, status in ipairs(weaponsLicenseStatuses) do
                    if status == tempCharacter.weaponsLicense then
                        weaponsLicenseIndex = i - 1
                        break
                    end
                end

                exports["vMenu"]:AddList("edit_character_menu", "weapons_license", "~r~Weapons License",
                    json.encode(weaponsLicenseStatuses), weaponsLicenseIndex, "Weapons License Status",
                    function(_, _, selectedOption, isSelected)
                        tempCharacter.weaponsLicense = selectedOption
                    end)

                exports["vMenu"]:AddList("edit_character_menu", "job_selection", "~b~Job", json.encode(jobsList),
                        jobIndex,
                        "Select a job", function(_, _, selectedOption, isSelected)
                            tempCharacter.job = string.lower(selectedOption)
                        end)

                local genderIndex = 0
                for index, gender in pairs(Config.Genders) do
                    if gender == tempCharacter.gender then
                        genderIndex = index - 1
                    end
                end

                exports["vMenu"]:AddList("edit_character_menu", "gender_selection", "~y~Gender",
                    json.encode(Config.Genders),
                    genderIndex, "Select a gender", function(_, _, selectedOption, isSelected)
                        tempCharacter.gender = selectedOption
                    end)

                local ethnicityIndex = 0
                for index, ethnicity in pairs(Config.Ethnicities) do
                    if ethnicity == tempCharacter.ethnicity then
                        ethnicityIndex = index - 1
                    end
                end

                exports["vMenu"]:AddList("edit_character_menu", "ethnicity_selection", "~y~Ethnicity",
                    json.encode(Config.Ethnicities), ethnicityIndex, "Select an ethnicity",
                    function(_, _, selectedOption, isSelected)
                        tempCharacter.ethnicity = selectedOption
                    end)

                if character and character.id then
                    exports["vMenu"]:AddButton("edit_character_menu", "delete_character", "~r~Delete Character",
                        "Permanently delete this character", function()
                            TriggerServerEvent("framework:characters:delete", character.id)
                            exports["vMenu"]:Notify("Character deleted!", "info")
                            exports["vMenu"]:OpenMenu("characters_menu")
                        end)
                end

                exports["vMenu"]:AddButton("edit_character_menu", "save_character", "~g~Save Character",
                    "Save the character details", function()
                        if (tempCharacter.name == "" or tempCharacter.dob == "") then
                            exports["vMenu"]:Notify("Please fill out all values!", "error")
                        else
                            TriggerServerEvent("framework:characters:save", tempCharacter)
                            --exports["vMenu"]:Notify(character and "Character updated!" or "Character created!", "success")
                            exports["vMenu"]:OpenMenu("characters_menu")
                        end
                    end)
            end

            function generateVIN(vehicleData)
                local function encode(input)
                    local hash = 0
                    for i = 1, #input do
                        hash = (hash + string.byte(input, i)) % 65536
                    end
                    return string.format("%04X", hash)
                end

                local chars = {}

                -- Randomly distribute make, model, colors, etc.
                chars[math.random(1, 17)] = vehicleData.make:sub(1, 1):upper()
                chars[math.random(1, 17)] = vehicleData.model:sub(1, 1):upper()
                chars[math.random(1, 17)] = string.format("%X", #vehicleData.make % 16)

                chars[math.random(1, 17)] = encode(vehicleData.type):sub(1, 1)
                chars[math.random(1, 17)] = encode(vehicleData.primaryColor):sub(1, 1)
                chars[math.random(1, 17)] = encode(vehicleData.secondaryColor):sub(1, 1)
                chars[math.random(1, 17)] = encode(vehicleData.model):sub(1, 1)

                local nameHash = encode(curChar.name)
                local plateHash = encode(vehicleData.plate)

                chars[math.random(1, 17)] = nameHash:sub(1, 1)
                chars[math.random(1, 17)] = plateHash:sub(1, 1)

                -- Fill remaining spots
                for i = 1, 17 do
                    if not chars[i] then
                        chars[i] = string.format("%X", math.random(0, 15))
                    end
                end

                return table.concat(chars)
            end

            function getInput(prompt, defaultText)
                AddTextEntry("FMMC_KEY_TIP1", prompt)
                DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP1", "", defaultText or "", "", "", "", 30)
                while UpdateOnscreenKeyboard() == 0 do
                    DisableAllControlActions(0)
                    Wait(0)
                end
                if GetOnscreenKeyboardResult() then
                    return GetOnscreenKeyboardResult()
                end
                return nil
            end

            local colorNames = {
                ['0'] = "Metallic Black",
                ['1'] = "Metallic Graphite Black",
                ['2'] = "Metallic Black Steal",
                ['3'] = "Metallic Dark Silver",
                ['4'] = "Metallic Silver",
                ['5'] = "Metallic Blue Silver",
                ['6'] = "Metallic Steel Gray",
                ['7'] = "Metallic Shadow Silver",
                ['8'] = "Metallic Stone Silver",
                ['9'] = "Metallic Midnight Silver",
                ['10'] = "Metallic Gun Metal",
                ['11'] = "Metallic Anthracite Grey",
                ['12'] = "Matte Black",
                ['13'] = "Matte Gray",
                ['14'] = "Matte Light Grey",
                ['15'] = "Util Black",
                ['16'] = "Util Black Poly",
                ['17'] = "Util Dark silver",
                ['18'] = "Util Silver",
                ['19'] = "Util Gun Metal",
                ['20'] = "Util Shadow Silver",
                ['21'] = "Worn Black",
                ['22'] = "Worn Graphite",
                ['23'] = "Worn Silver Grey",
                ['24'] = "Worn Silver",
                ['25'] = "Worn Blue Silver",
                ['26'] = "Worn Shadow Silver",
                ['27'] = "Metallic Red",
                ['28'] = "Metallic Torino Red",
                ['29'] = "Metallic Formula Red",
                ['30'] = "Metallic Blaze Red",
                ['31'] = "Metallic Graceful Red",
                ['32'] = "Metallic Garnet Red",
                ['33'] = "Metallic Desert Red",
                ['34'] = "Metallic Cabernet Red",
                ['35'] = "Metallic Candy Red",
                ['36'] = "Metallic Sunrise Orange",
                ['37'] = "Metallic Classic Gold",
                ['38'] = "Metallic Orange",
                ['39'] = "Matte Red",
                ['40'] = "Matte Dark Red",
                ['41'] = "Matte Orange",
                ['42'] = "Matte Yellow",
                ['43'] = "Util Red",
                ['44'] = "Util Bright Red",
                ['45'] = "Util Garnet Red",
                ['46'] = "Worn Red",
                ['47'] = "Worn Golden Red",
                ['48'] = "Worn Dark Red",
                ['49'] = "Metallic Dark Green",
                ['50'] = "Metallic Racing Green",
                ['51'] = "Metallic Sea Green",
                ['52'] = "Metallic Olive Green",
                ['53'] = "Metallic Green",
                ['54'] = "Metallic Gasoline Blue Green",
                ['55'] = "Matte Lime Green",
                ['56'] = "Util Dark Green",
                ['57'] = "Util Green",
                ['58'] = "Worn Dark Green",
                ['59'] = "Worn Green",
                ['60'] = "Worn Sea Wash",
                ['61'] = "Metallic Midnight Blue",
                ['62'] = "Metallic Dark Blue",
                ['63'] = "Metallic Saxony Blue",
                ['64'] = "Metallic Blue",
                ['65'] = "Metallic Mariner Blue",
                ['66'] = "Metallic Harbor Blue",
                ['67'] = "Metallic Diamond Blue",
                ['68'] = "Metallic Surf Blue",
                ['69'] = "Metallic Nautical Blue",
                ['70'] = "Metallic Bright Blue",
                ['71'] = "Metallic Purple Blue",
                ['72'] = "Metallic Spinnaker Blue",
                ['73'] = "Metallic Ultra Blue",
                ['74'] = "Metallic Bright Blue",
                ['75'] = "Util Dark Blue",
                ['76'] = "Util Midnight Blue",
                ['77'] = "Util Blue",
                ['78'] = "Util Sea Foam Blue",
                ['79'] = "Uil Lightning blue",
                ['80'] = "Util Maui Blue Poly",
                ['81'] = "Util Bright Blue",
                ['82'] = "Matte Dark Blue",
                ['83'] = "Matte Blue",
                ['84'] = "Matte Midnight Blue",
                ['85'] = "Worn Dark blue",
                ['86'] = "Worn Blue",
                ['87'] = "Worn Light blue",
                ['88'] = "Metallic Taxi Yellow",
                ['89'] = "Metallic Race Yellow",
                ['90'] = "Metallic Bronze",
                ['91'] = "Metallic Yellow Bird",
                ['92'] = "Metallic Lime",
                ['93'] = "Metallic Champagne",
                ['94'] = "Metallic Pueblo Beige",
                ['95'] = "Metallic Dark Ivory",
                ['96'] = "Metallic Choco Brown",
                ['97'] = "Metallic Golden Brown",
                ['98'] = "Metallic Light Brown",
                ['99'] = "Metallic Straw Beige",
                ['100'] = "Metallic Moss Brown",
                ['101'] = "Metallic Biston Brown",
                ['102'] = "Metallic Beechwood",
                ['103'] = "Metallic Dark Beechwood",
                ['104'] = "Metallic Choco Orange",
                ['105'] = "Metallic Beach Sand",
                ['106'] = "Metallic Sun Bleeched Sand",
                ['107'] = "Metallic Cream",
                ['108'] = "Util Brown",
                ['109'] = "Util Medium Brown",
                ['110'] = "Util Light Brown",
                ['111'] = "Metallic White",
                ['112'] = "Metallic Frost White",
                ['113'] = "Worn Honey Beige",
                ['114'] = "Worn Brown",
                ['115'] = "Worn Dark Brown",
                ['116'] = "Worn straw beige",
                ['117'] = "Brushed Steel",
                ['118'] = "Brushed Black steel",
                ['119'] = "Brushed Aluminium",
                ['120'] = "Chrome",
                ['121'] = "Worn Off White",
                ['122'] = "Util Off White",
                ['123'] = "Worn Orange",
                ['124'] = "Worn Light Orange",
                ['125'] = "Metallic Securicor Green",
                ['126'] = "Worn Taxi Yellow",
                ['127'] = "police car blue",
                ['128'] = "Matte Green",
                ['129'] = "Matte Brown",
                ['130'] = "Worn Orange",
                ['131'] = "Matte White",
                ['132'] = "Worn White",
                ['133'] = "Worn Olive Army Green",
                ['134'] = "Pure White",
                ['135'] = "Hot Pink",
                ['136'] = "Salmon pink",
                ['137'] = "Metallic Vermillion Pink",
                ['138'] = "Orange",
                ['139'] = "Green",
                ['140'] = "Blue",
                ['141'] = "Mettalic Black Blue",
                ['142'] = "Metallic Black Purple",
                ['143'] = "Metallic Black Red",
                ['144'] = "hunter green",
                ['145'] = "Metallic Purple",
                ['146'] = "Metaillic V Dark Blue",
                ['147'] = "MODSHOP BLACK1",
                ['148'] = "Matte Purple",
                ['149'] = "Matte Dark Purple",
                ['150'] = "Metallic Lava Red",
                ['151'] = "Matte Forest Green",
                ['152'] = "Matte Olive Drab",
                ['153'] = "Matte Desert Brown",
                ['154'] = "Matte Desert Tan",
                ['155'] = "Matte Foilage Green",
                ['156'] = "DEFAULT ALLOY COLOR",
                ['157'] = "Epsilon Blue",
            }

            local function GetVehicleClassName(vehicleClass)
                local classNames = {
                    [0] = "Compact",
                    [1] = "Sedan",
                    [2] = "SUV",
                    [3] = "Coupe",
                    [4] = "Muscle",
                    [5] = "Sports Classic",
                    [6] = "Sports",
                    [7] = "Super",
                    [8] = "Motorcycle",
                    [9] = "Off-road",
                    [10] = "Industrial",
                    [11] = "Utility",
                    [12] = "Van",
                    [13] = "Cycle",
                    [14] = "Boat",
                    [15] = "Helicopter",
                    [16] = "Plane",
                    [17] = "Service",
                    [18] = "Emergency",
                    [19] = "Military",
                    [20] = "Commercial",
                    [21] = "Train"
                }
                return classNames[vehicleClass] or "Unknown"
            end

            function GetVehicleDetails(vehicle)
                local modelHash = GetEntityModel(vehicle)
                local model = GetLabelText(GetDisplayNameFromVehicleModel(modelHash)) -- Vehicle make
                local make = GetLabelText(GetMakeNameFromVehicleModel(modelHash))     -- Vehicle model
                local vehicleClass = GetVehicleClass(vehicle)                         -- Type as class
                local primary, secondary = GetVehicleColours(vehicle)                 -- Vehicle colors
                local primaryColor = colorNames[tostring(primary)] or "Unknown Color"
                local secondaryColor = colorNames[tostring(secondary)] or "Unknown Color"

                return {
                    make = make ~= "NULL" and make or "Unknown Make",
                    model = model ~= "NULL" and model or "Unknown Model",
                    type = GetVehicleClassName(vehicleClass), -- Convert class to readable name
                    primaryColor = primaryColor,
                    secondaryColor = secondaryColor
                }
            end

            exports("getVehicles", function()
                return vehicles
            end)

            exports("getCharacter", function()
                if curChar then
                    curChar.jobType = getJobType(curChar.job)
                end
                return curChar
            end)

            exports("getAllVehicles", function()
                return allVehicles
            end)

            exports("getAllCharacters", function()
                -- Add jobType for each character
                for _, character in ipairs(allCharacters) do
                    character.jobType = getJobType(character.job)
                end
                return allCharacters
            end)

            initRoleplayMenus()
        end
    end
}
