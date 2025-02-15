--[[
    vMenu PMA Voice Management Plugin
    Add 'PMAVoice' to your enabled plugins list.
    Add: dependency 'pma-voice'    to the fxmanifest
]]

PMAVoice = {
    name = "PMA Voice Plugin",
    version = "1.0.0",
    author = "TIMMYG",
    dependencies = {},
    mainSubMenu = { -- Optionally add a main submenu for your plugin
        id = "pma_voice",
        title = "Voice Chat Settings",
        desc = "Change Voice Chat options here.",
        position = 4.5
    },
    init = function()
        if not IsDuplicityVersion() then
            function populateVoiceMenu()
                exports["vMenu"]:ClearMenu("pma_voice")
                if GetConvarInt('voice_enableProximityCycle', 1) ~= 1 or disableProximityCycle then return end
                local proximity = LocalPlayer.state['proximity']
                if not proximity or not proximity.mode then proximity = { mode = "Normal" } end
                exports["vMenu"]:AddButton("pma_voice", "cycle_proximity",
                    "Cycle Proximity ~b~(" .. proximity.mode .. ")",
                    "Current Range: ~b~" .. proximity.mode,
                    function()
                        ExecuteCommand("cycleproximity")
                        populateVoiceMenu()
                    end)

                local defaultVoiceIntent = LocalPlayer.state['voiceIntent']
                if not defaultVoiceIntent then defaultVoiceIntent = "speech" end
                local defaultVoiceToggle = defaultVoiceIntent == "speech"
                exports["vMenu"]:AddCheckbox("pma_voice", "voice_toggle", "Enable Noise Suppression",
                    "Enable or disable noise suppression", defaultVoiceToggle, function(isChecked)
                        local result = isChecked and "speech" or "music"
                        ExecuteCommand("setvoiceintent " .. result)
                    end)

                local micClicksKvp = GetResourceKvpString('pma-voice_enableMicClicks')
                if not micClicksKvp then micClicksKvp = true end
                exports["vMenu"]:AddCheckbox("pma_voice", "voice_toggle", "Enable Radio Mic Clicks",
                    "Enable or disable radio mic clicks", micClicksKvp, function(isChecked)
                        exports['pma-voice']:setVoiceProperty('micClicks', isChecked)
                    end)

                local radioAnimState = exports["pma-voice"]:getRadioAnimState()
                if not radioAnimState then radioAnimState = true end
                exports["vMenu"]:AddCheckbox("pma_voice", "anim_toggle", "Enable Radio PTT Animation",
                    "Enable or disable radio PTT animation", micClicksKvp, function(isChecked)
                        exports['pma-voice']:setDisableRadioAnim(not isChecked)
                    end)
            end

            populateVoiceMenu()
        end
    end
}
