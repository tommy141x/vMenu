--[[
    Cinematic Camera Plugin for vMenu
    Provides advanced camera controls with menu integration

    Add: 'CinematicCamPlugin' to your enabled plugins list.
]]

CinematicCamPlugin = {
    name = "Cinematic Camera Plugin",
    version = "1.0.0",
    author = "TIMMYG",
    dependencies = {},
    mainSubMenu = {
        id = "cinematic_cam",
        title = "Camera Options",
        desc = "Take some dope screenshots.",
        position = 5 -- Should be the second submenu button in the main menu
    },
    init = function()
        if not IsDuplicityVersion() then
            local Config             = {}

            ----------------------
            -- General settings --
            ----------------------
            Config.maxDistance       = 500.0
            Config.disableAttach     = false

            Config.minSpeed          = 0.1
            Config.maxSpeed          = 10.0

            Config.minPrecision      = 0.1
            Config.incrPrecision     = 0.1
            Config.maxPrecision      = 2.0

            Config.minFov            = 1.0
            Config.maxFov            = 130.0

            Config.controls          = {
                keyboard = {
                    openMenu  = 178, -- Delete
                    hold      = 21,  -- Shift
                    speedUp   = 15,  -- Mouse wheel up   -- with hold
                    speedDown = 14,  -- Mouse wheel down -- with hold

                    zoomOut   = 14,  -- Mouse wheel down
                    zoomIn    = 15,  -- Mouse wheel up

                    forwards  = 32,  -- W
                    backwards = 33,  -- S
                    left      = 34,  -- A
                    right     = 35,  -- D
                    up        = 22,  -- Space
                    down      = 36,  -- Ctrl

                    rollLeft  = 44,  -- Q
                    rollRight = 38,  -- E
                },
                controller = {
                    openMenu  = 244, -- Select -- hold for ~1 second

                    holdSpeed = 80,  -- O / B
                    holdFov   = 21,  -- X / A
                    up        = 172, -- D-pad up
                    down      = 173, -- D-pad down

                    rollLeft  = 37,  -- L1 / LB
                    rollRight = 44,  -- R1 / RB
                }
            }

            -- disables character/vehicle controls when using camera movements
            Config.disabledControls  = {
                30,  -- A and D (Character Movement)
                31,  -- W and S (Character Movement)
                21,  -- LEFT SHIFT
                36,  -- LEFT CTRL
                22,  -- SPACE
                44,  -- Q
                38,  -- E
                71,  -- W (Vehicle Movement)
                72,  -- S (Vehicle Movement)
                59,  -- A and D (Vehicle Movement)
                60,  -- LEFT SHIFT and LEFT CTRL (Vehicle Movement)
                85,  -- Q (Radio Wheel)
                86,  -- E (Vehicle Horn)
                15,  -- Mouse wheel up
                14,  -- Mouse wheel down
                37,  -- Controller R1 (PS) / RT (XBOX)
                80,  -- Controller O (PS) / B (XBOX)
                228, --
                229, --
                172, --
                173, --
                37,  --
                44,  --
                178, --
                244, --
            }

            Config.menuTitle         = "Cinematic Cam"
            Config.menuSubtitle      = "Control the Cinematic Camera"
            Config.toggleCam         = "Camera Active"
            Config.toggleCamDesc     = "Toggle camera on/off"
            Config.precision         = "Camera Precision"
            Config.precisionDesc     = "Change camera precision movement"
            Config.showMap           = "Show Minimap"
            Config.showMapDesc       = "Toggle minimap on/off"
            Config.freeFly           = "Toggle Free Fly Mode"
            Config.freeFlyDesc       = "Switch to Free Fly or back to Drone Mode"
            Config.charControl       = "Toggle Character Control"
            Config.charControlDesc   = "Switch to Character or back to Camera Control"
            Config.attachCam         = "Attach to Entity"
            Config.attachCamDesc     = "Attach the Camera to the entity in front of the camera"

            -- Main camera variables
            local cam                = nil
            local offsetRotX         = 0.0
            local offsetRotY         = 0.0
            local offsetRotZ         = 0.0

            local offsetCoords       = { x = 0.0, y = 0.0, z = 0.0 }

            local speed              = 1.0
            local precision          = 1.0
            local freeFly            = false
            local charControl        = false
            local isAttached         = false
            local entity             = nil

            -- Prepare precision list
            local precisions         = {}
            local counter            = 0
            local currPrecisionIndex = 1

            for i = Config.minPrecision, Config.maxPrecision + 0.01, Config.incrPrecision do
                table.insert(precisions, tostring(i))
                counter = counter + 1
                if (tostring(i) == "1.0") then
                    currPrecisionIndex = counter
                end
            end

            function createCinematicCamMenu()
                -- Camera toggle checkbox
                exports["vMenu"]:AddCheckbox("cinematic_cam", "toggle_cam", Config.toggleCam,
                    Config.toggleCamDesc, false, function(isChecked)
                        ToggleCam(isChecked, GetGameplayCamFov())
                    end)

                -- Precision list
                exports["vMenu"]:AddList("cinematic_cam", "cam_precision", Config.precision,
                    json.encode(precisions), currPrecisionIndex - 1, Config.precisionDesc,
                    function(oldIndex, newIndex, selectedOption)
                        precision = tonumber(selectedOption)
                    end)

                -- Show map checkbox
                exports["vMenu"]:AddCheckbox("cinematic_cam", "show_map", Config.showMap,
                    Config.showMapDesc, true, function(isChecked)
                        ToggleUI(isChecked)
                    end)

                -- Free fly mode checkbox
                exports["vMenu"]:AddCheckbox("cinematic_cam", "free_fly", Config.freeFly,
                    Config.freeFlyDesc, freeFly, function(isChecked)
                        ToggleFreeFlyMode(isChecked)
                    end)

                -- Character control checkbox
                exports["vMenu"]:AddCheckbox("cinematic_cam", "char_control", Config.charControl,
                    Config.charControlDesc, charControl, function(isChecked)
                        ToggleCharacterControl(isChecked)
                    end)

                -- Attach camera option
                if not Config.disableAttach then
                    exports["vMenu"]:AddButton("cinematic_cam", "attach_camera", Config.attachCam,
                        Config.attachCamDesc, function()
                            ToggleAttachMode()
                        end)
                end
            end

            Citizen.CreateThread(function()
                local pressedCount = 0
                while true do
                    Citizen.Wait(1)

                    -- process cam controls if cam exists
                    if (cam) then
                        ProcessCamControls()
                    end
                end
            end)

            if (not Config.disableAttach) then
                Citizen.CreateThread(function()
                    while true do
                        Citizen.Wait(500)
                        if (cam) then
                            if (isAttached and not DoesEntityExist(entity)) then
                                isAttached = false
                                ClearFocus()
                                StopCamPointing(cam)
                            end
                        end
                    end
                end)
            end

            --------------------------------------------------
            ------------------- FUNCTIONS --------------------
            --------------------------------------------------

            -- initialize camera
            function StartFreeCam(fov)
                ClearFocus()

                local playerPed = PlayerPedId()

                cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", GetEntityCoords(playerPed), 0, 0, 0, fov * 1.0)

                SetCamActive(cam, true)
                RenderScriptCams(true, false, 0, true, false)

                SetCamAffectsAiming(cam, false)

                if (Config.disableAttach) then
                    ToggleAttachMode(PlayerPedId())
                end

                if (isAttached and DoesEntityExist(entity)) then
                    offsetCoords = GetOffsetFromEntityGivenWorldCoords(entity, GetCamCoord(cam))

                    AttachCamToEntity(cam, entity, offsetCoords.x, offsetCoords.y, offsetCoords.z, true)
                end
            end

            -- destroy camera
            function EndFreeCam()
                ClearFocus()

                RenderScriptCams(false, false, 0, true, false)
                DestroyCam(cam, false)

                offsetRotX = 0.0
                offsetRotY = 0.0
                offsetRotZ = 0.0

                isAttached = false

                speed      = 1.0
                precision  = 1.0
                currFov    = GetGameplayCamFov()

                cam        = nil
            end

            -- process camera controls
            function ProcessCamControls()
                local playerPed = PlayerPedId()

                -- Disable 1st person as the 1st person camera can cause some glitches
                DisableFirstPersonCamThisFrame()
                -- Block weapon wheel (reason: scrolling)
                BlockWeaponWheelThisFrame()
                -- Disable character/vehicle controls
                if (not charControl) then
                    for k, v in pairs(Config.disabledControls) do
                        DisableControlAction(0, v, true)
                    end
                end

                -- Dynamically adjust speed based on precision
                speed = Config.minSpeed +
                    (precision - Config.minPrecision) / (Config.maxPrecision - Config.minPrecision) *
                    (Config.maxSpeed - Config.minSpeed)

                if (isAttached) then
                    -- Calculate new position
                    offsetCoords = ProcessNewPosition(offsetCoords.x, offsetCoords.y, offsetCoords.z)

                    -- Focus entity
                    SetFocusEntity(entity)

                    -- Reset coords of cam if too far from entity
                    local distance = #(vector3(offsetCoords.x, offsetCoords.y, offsetCoords.z))
                    if (distance > Config.maxDistance) then
                        local direction = vector3(offsetCoords.x, offsetCoords.y, offsetCoords.z) / distance
                        offsetCoords = direction * Config.maxDistance
                    end

                    -- Set coords
                    AttachCamToEntity(cam, entity, offsetCoords.x, offsetCoords.y, offsetCoords.z, true)

                    -- Set rotation
                    local entityRot = GetEntityRotation(entity, 2)
                    SetCamRot(cam, entityRot.x + offsetRotX, entityRot.y + offsetRotY, entityRot.z + offsetRotZ, 2)
                else
                    local camCoords = GetCamCoord(cam)
                    local playerCoords = GetEntityCoords(PlayerPedId())

                    -- Calculate distance between camera and player
                    local distance = #(vector3(camCoords.x, camCoords.y, camCoords.z) - playerCoords)

                    -- Reset position if too far from player
                    if (distance > Config.maxDistance) then
                        local factor = distance / Config.maxDistance
                        camCoords = vector3(playerCoords.x + (camCoords.x - playerCoords.x) / factor,
                            playerCoords.y + (camCoords.y - playerCoords.y) / factor,
                            playerCoords.z + (camCoords.z - playerCoords.z) / factor)
                    end

                    -- Calculate new position
                    local newPos = ProcessNewPosition(camCoords.x, camCoords.y, camCoords.z)

                    -- Focus cam area
                    SetFocusArea(newPos.x, newPos.y, newPos.z, 0.0, 0.0, 0.0)

                    -- Set coords of cam
                    SetCamCoord(cam, newPos.x, newPos.y, newPos.z)

                    -- Set rotation
                    SetCamRot(cam, offsetRotX, offsetRotY, offsetRotZ, 2)
                end
            end

            function ProcessNewPosition(x, y, z)
                local _x = x
                local _y = y
                local _z = z

                -- keyboard
                if (IsInputDisabled(0) and not charControl) then
                    if (IsDisabledControlPressed(1, Config.controls.keyboard.forwards)) then
                        local multX = Sin(offsetRotZ)
                        local multY = Cos(offsetRotZ)
                        local multZ = Sin(offsetRotX)

                        _x = _x - (0.1 * speed * multX)
                        _y = _y + (0.1 * speed * multY)
                        if (freeFly) then
                            _z = _z + (0.1 * speed * multZ)
                        end
                    end
                    if (IsDisabledControlPressed(1, Config.controls.keyboard.backwards)) then
                        local multX = Sin(offsetRotZ)
                        local multY = Cos(offsetRotZ)
                        local multZ = Sin(offsetRotX)

                        _x = _x + (0.1 * speed * multX)
                        _y = _y - (0.1 * speed * multY)
                        if (freeFly) then
                            _z = _z - (0.1 * speed * multZ)
                        end
                    end
                    if (IsDisabledControlPressed(1, Config.controls.keyboard.left)) then
                        local multX = Sin(offsetRotZ + 90.0)
                        local multY = Cos(offsetRotZ + 90.0)
                        local multZ = Sin(offsetRotY)

                        _x = _x - (0.1 * speed * multX)
                        _y = _y + (0.1 * speed * multY)
                        if (freeFly) then
                            _z = _z + (0.1 * speed * multZ)
                        end
                    end
                    if (IsDisabledControlPressed(1, Config.controls.keyboard.right)) then
                        local multX = Sin(offsetRotZ + 90.0)
                        local multY = Cos(offsetRotZ + 90.0)
                        local multZ = Sin(offsetRotY)

                        _x = _x + (0.1 * speed * multX)
                        _y = _y - (0.1 * speed * multY)
                        if (freeFly) then
                            _z = _z - (0.1 * speed * multZ)
                        end
                    end

                    if (IsDisabledControlPressed(1, Config.controls.keyboard.up)) then
                        _z = _z + (0.1 * speed)
                    end
                    if (IsDisabledControlPressed(1, Config.controls.keyboard.down)) then
                        _z = _z - (0.1 * speed)
                    end


                    if (IsDisabledControlPressed(1, Config.controls.keyboard.hold)) then
                        -- hotkeys for speed
                        if (IsDisabledControlPressed(1, Config.controls.keyboard.speedUp)) then
                            if ((speed + 0.1) < Config.maxSpeed) then
                                speed = speed + 0.1
                            else
                                speed = Config.maxSpeed
                            end
                        elseif (IsDisabledControlPressed(1, Config.controls.keyboard.speedDown)) then
                            if ((speed - 0.1) > Config.minSpeed) then
                                speed = speed - 0.1
                            else
                                speed = Config.minSpeed
                            end
                        end
                    else
                        -- hotkeys for FoV
                        if (IsDisabledControlPressed(1, Config.controls.keyboard.zoomOut)) then
                            ChangeFov(1.0)
                        elseif (IsDisabledControlPressed(1, Config.controls.keyboard.zoomIn)) then
                            ChangeFov(-1.0)
                        end
                    end

                    -- rotation
                    offsetRotX = offsetRotX - (GetDisabledControlNormal(1, 2) * precision * 8.0)
                    offsetRotZ = offsetRotZ - (GetDisabledControlNormal(1, 1) * precision * 8.0)
                    if (IsDisabledControlPressed(1, Config.controls.keyboard.rollLeft)) then
                        offsetRotY = offsetRotY - precision
                    end
                    if (IsDisabledControlPressed(1, Config.controls.keyboard.rollRight)) then
                        offsetRotY = offsetRotY + precision
                    end

                    -- controller
                elseif (not charControl) then
                    local multX = Sin(offsetRotZ)
                    local multY = Cos(offsetRotZ)
                    local multZ = Sin(offsetRotX)

                    _x = _x - (0.1 * speed * multX * GetDisabledControlNormal(1, 32))
                    _y = _y + (0.1 * speed * multY * GetDisabledControlNormal(1, 32))
                    if (freeFly) then
                        _z = _z + (0.1 * speed * multZ * GetDisabledControlNormal(1, 32))
                    end

                    _x = _x + (0.1 * speed * multX * GetDisabledControlNormal(1, 33))
                    _y = _y - (0.1 * speed * multY * GetDisabledControlNormal(1, 33))
                    if (freeFly) then
                        _z = _z - (0.1 * speed * multZ * GetDisabledControlNormal(1, 33))
                    end

                    multX = Sin(offsetRotZ + 90.0)
                    multY = Cos(offsetRotZ + 90.0)
                    local multZ = Sin(offsetRotY)
                    _x = _x - (0.1 * speed * multX * GetDisabledControlNormal(1, 34))
                    _y = _y + (0.1 * speed * multY * GetDisabledControlNormal(1, 34))
                    if (freeFly) then
                        _z = _z + (0.1 * speed * multZ * GetDisabledControlNormal(1, 34))
                    end

                    _x = _x + (0.1 * speed * multX * GetDisabledControlNormal(1, 35))
                    _y = _y - (0.1 * speed * multY * GetDisabledControlNormal(1, 35))
                    if (freeFly) then
                        _z = _z - (0.1 * speed * multZ * GetDisabledControlNormal(1, 35))
                    end

                    -- FoV, Speed, Up/Down Movement
                    if (GetDisabledControlNormal(1, 228) ~= 0.0) then
                        if (IsDisabledControlPressed(1, Config.controls.controller.holdFov)) then
                            ChangeFov(GetDisabledControlNormal(1, 228))
                        elseif (IsDisabledControlPressed(1, Config.controls.controller.holdSpeed)) then
                            local newSpeed = speed - (0.1 * GetDisabledControlNormal(1, 228))
                            if (newSpeed > Config.minSpeed) then
                                speed = newSpeed
                            else
                                speed = Config.minSpeed
                            end
                        else
                            _z = _z - (0.1 * speed * GetDisabledControlNormal(1, 228))
                        end
                    end
                    if (GetDisabledControlNormal(1, 229) ~= 0.0) then
                        if (IsDisabledControlPressed(1, Config.controls.controller.holdFov)) then
                            ChangeFov(-GetDisabledControlNormal(1, 229))
                        elseif (IsDisabledControlPressed(1, Config.controls.controller.holdSpeed)) then
                            local newSpeed = speed + (0.1 * GetDisabledControlNormal(1, 229))
                            if (newSpeed < Config.maxSpeed) then
                                speed = newSpeed
                            else
                                speed = Config.maxSpeed
                            end
                        else
                            _z = _z + (0.1 * speed * GetDisabledControlNormal(1, 229))
                        end
                    end

                    -- rotation
                    offsetRotX = offsetRotX - (GetDisabledControlNormal(1, 2) * precision)
                    offsetRotZ = offsetRotZ - (GetDisabledControlNormal(1, 1) * precision)
                    if (IsDisabledControlPressed(1, Config.controls.controller.rollLeft)) then
                        offsetRotY = offsetRotY - precision
                    end
                    if (IsDisabledControlPressed(1, Config.controls.controller.rollRight)) then
                        offsetRotY = offsetRotY + precision
                    end
                end

                if (offsetRotX > 90.0) then offsetRotX = 90.0 elseif (offsetRotX < -90.0) then offsetRotX = -90.0 end
                if (offsetRotY > 90.0) then offsetRotY = 90.0 elseif (offsetRotY < -90.0) then offsetRotY = -90.0 end
                if (offsetRotZ > 360.0) then
                    offsetRotZ = offsetRotZ - 360.0
                elseif (offsetRotZ < -360.0) then
                    offsetRotZ =
                        offsetRotZ + 360.0
                end

                return { x = _x, y = _y, z = _z }
            end

            function ToggleCam(flag, fov)
                if (flag) then
                    StartFreeCam(fov)
                else
                    EndFreeCam()
                end
            end

            function ChangeFov(changeFov)
                if (DoesCamExist(cam)) then
                    local currFov = GetCamFov(cam)
                    local newFov  = currFov + changeFov

                    if ((newFov >= Config.minFov) and (newFov <= Config.maxFov)) then
                        SetCamFov(cam, newFov)
                    end
                end
            end

            function ChangePrecision(newindex)
                precision          = itemCamPrecision.Items[newindex]
                currPrecisionIndex = newindex
            end

            function ToggleUI(flag)
                DisplayRadar(flag)
            end

            function ToggleFreeFlyMode(flag)
                freeFly = flag
            end

            function GetEntityInFrontOfCam()
                local camCoords = GetCamCoord(cam)
                local offset = {
                    x = camCoords.x - Sin(offsetRotZ) * 100.0,
                    y = camCoords.y + Cos(offsetRotZ) * 100.0,
                    z = camCoords
                        .z + Sin(offsetRotX) * 100.0
                }

                local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, offset.x, offset.y, offset.z,
                    10, 0, 0)
                local a, b, c, d, entity = GetShapeTestResult(rayHandle)
                return entity
            end

            function ToggleCharacterControl(flag)
                charControl = flag
            end

            function ToggleAttachMode(playerEntity)
                if (not isAttached) then
                    entity = playerEntity or GetEntityInFrontOfCam()

                    if (DoesEntityExist(entity)) then
                        offsetCoords = GetOffsetFromEntityGivenWorldCoords(entity, GetCamCoord(cam))

                        Citizen.Wait(1)
                        local camCoords = GetCamCoord(cam)
                        AttachCamToEntity(cam, entity,
                            GetOffsetFromEntityInWorldCoords(entity, camCoords.x, camCoords.y, camCoords.z), true)

                        isAttached = true
                    end
                else
                    ClearFocus()

                    DetachCam(cam)

                    isAttached = false
                end
            end

            createCinematicCamMenu()
        end
    end
}
