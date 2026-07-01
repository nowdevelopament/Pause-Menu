-- Global state variables
local isNuiActive = false           -- Tracks if the custom NUI pause menu is currently open
local nuiCoolDownEndTime = 0        -- Timestamp for NUI menu cooldown (prevents rapid re-opening)
local isFrontendMenuOpen = false    -- Tracks if a FiveM frontend menu (like map/settings) is currently active
local frontendMenuCloseTime = 0     -- Timestamp for when an opened frontend menu should automatically close

-- Helper function to get the player's character name
-- Tries to get it from ESX data, falls back to GetPlayerName, defaults to "--"
function getPlayerCharacterName()
    if ESX and ESX.GetPlayerData then
        local playerData = ESX.GetPlayerData()
        if playerData and playerData.name and playerData.name ~= "" then
            return playerData.name
        end
    end
    -- Fallback to default FiveM player name if ESX data is not available or incomplete
    local playerName = GetPlayerName(PlayerId())
    return playerName or "--"
end

-- Helper function to format numbers as currency (e.g., 1000000 -> 1.000.000)
-- Assumes `string.reverse` function is available (common in FiveM resource setups, usually Lua 5.1 global)
function formatCurrency(amount)
    local num = tonumber(amount)
    if not num then
        num = 0
    end

    local numStr = tostring(math.floor(num))

    -- Use string.reverse from Lua's standard string library
    local reversedStr = string.reverse(numStr)
    local formattedReversed = reversedStr:gsub("(%d%d%d)", "%1.")
    local finalFormatted = string.reverse(formattedReversed)
    return finalFormatted:gsub("^%.", "") -- Remove leading dot if any
end

-- Helper function to collect detailed player data (name, job, cash, bank)
function getPlayerDataInfo()
    local playerData = {}
    if ESX then
        if ESX.GetPlayerData then
            playerData = ESX.GetPlayerData() or {}
        elseif ESX.PlayerData then -- Fallback for older ESX versions or different initialization
            playerData = ESX.PlayerData or {}
        end
    end

    local firstName = ""
    local lastName = ""

    -- Try to get firstName from various possible fields
    firstName = playerData.firstName or playerData.firstname or ""

    -- Try to get lastName from various possible fields
    lastName = playerData.lastName or playerData.lastname or ""

    -- If names are still empty, check playerData.variables (some ESX versions store it here)
    if (firstName == "" or lastName == "") and type(playerData.variables) == "table" then
        if firstName == "" then
            firstName = playerData.variables.firstName or playerData.variables.firstname or ""
        end
        if lastName == "" then
            lastName = playerData.variables.lastName or playerData.variables.lastname or ""
        end
    end

    -- If names are still empty, try parsing from playerData.name (e.g., "John Doe")
    if (firstName == "" or lastName == "") and type(playerData.name) == "string" and playerData.name ~= "" then
        local nameParts = {}
        for part in string.gmatch(playerData.name, "%S+") do
            table.insert(nameParts, part)
        end
        if firstName == "" then
            firstName = nameParts[1] or playerData.name -- Fallback to full name if only one part
        end
        if lastName == "" then
            lastName = nameParts[2] or ""
        end
    end

    -- Ensure names are not empty, default to "--" if still blank
    firstName = firstName ~= "" and firstName or "--"
    lastName = lastName ~= "" and lastName or "--"

    -- Collect job information
    local jobInfo = "--"
    if playerData.job then
        local jobLabel = playerData.job.label or playerData.job.name or "--"
        local jobGradeLabel = playerData.job.grade_label or playerData.job.grade_name
        if jobGradeLabel and jobGradeLabel ~= "" then
            jobInfo = string.format("%s - %s", jobLabel, jobGradeLabel)
        else
            jobInfo = jobLabel
        end
    end

    -- Collect money information
    local cashAmount = 0
    local bankAmount = 0

    if playerData.accounts then
        -- Iterate through accounts to find cash and bank
        for i = 1, #playerData.accounts do
            local account = playerData.accounts[i]
            if account then
                if account.name == "bank" then
                    bankAmount = account.money or account.balance or 0
                elseif account.name == "money" or account.name == "cash" then
                    cashAmount = account.money or account.balance or 0
                end
            end
        end
    elseif playerData.money then -- Older ESX versions might have 'money' directly for cash
        cashAmount = playerData.money
    end

    -- Return structured player data
    return {
        firstName = firstName,
        lastName = lastName,
        job = jobInfo,
        cash = formatCurrency(cashAmount),
        bank = formatCurrency(bankAmount)
    }
end

-- Function to open the custom NUI pause menu
function openPauseMenuNUI()
    if isNuiActive then
        return -- Menu already open
    end

    -- Cooldown check to prevent spamming menu opening after closing a frontend menu
    if GetGameTimer() < nuiCoolDownEndTime then
        return
    end

    -- Do not open if native pause menu is active or NUI is focused by another script
    if IsPauseMenuActive() or IsNuiFocused() then
        return
    end

    isNuiActive = true
    SetNuiFocus(true, true) -- Set NUI focus to capture input

    local data = getPlayerDataInfo()

    -- Send collected player data to the NUI
    SendNUIMessage({
        action = "open",
        playerId = GetPlayerServerId(PlayerId()),
        characterName = getPlayerCharacterName(),
        steamName = GetPlayerName(PlayerId()) or "--",
        firstName = data.firstName,
        lastName = data.lastName,
        job = data.job,
        cash = data.cash,
        bank = data.bank
    })
end

-- Function to close the custom NUI pause menu
function closePauseMenuNUI()
    if not isNuiActive then
        return -- Menu not open
    end

    isNuiActive = false
    SetNuiFocus(false, false) -- Release NUI focus
    SendNUIMessage({ action = "close" })
end

-- Register "now_pause" command
RegisterCommand("now_pause", function()
    openPauseMenuNUI()
end, false) -- Client-side command, not restricted to server-side

-- Register key mapping for "now_pause" command (Escape key)
RegisterKeyMapping("now_pause", "Apri Pause Menu", "keyboard", "ESCAPE")

-- NUI Callback for "close" action (triggered from NUI to close the menu)
RegisterNUICallback("close", function(data, cb)
    closePauseMenuNUI()
    cb(true) -- Acknowledge callback for NUI
end)

-- NUI Callback for "daily" action (triggered from NUI to execute a daily reward command)
RegisterNUICallback("daily", function(data, cb)
    closePauseMenuNUI()
    ExecuteCommand("riscattapremio")
    cb(true)
end)

-- NUI Callback for "support" action (triggered from NUI to execute a report command)
RegisterNUICallback("support", function(data, cb)
    closePauseMenuNUI()
    ExecuteCommand("report")
    cb(true)
end)

-- NUI Callback for "rules" action (triggered from NUI to potentially open a rules URL)
RegisterNUICallback("rules", function(data, cb)
    closePauseMenuNUI()
    local rulesUrl = data and data.url
    if rulesUrl and rulesUrl ~= "" then
        -- The original code only sends a chat message, it does NOT actually open the URL.
        -- If URL opening is intended, a client-side function like Citizen.InvokeNative('OPEN_URL_WEB_BROWSER', url)
        -- or similar would be needed. Keeping the original functionality of only a chat message.
        TriggerEvent("chat:addMessage", {
            args = {"^2NowRP", "Apro il regolamento nel browser..."}
        })
    end
    cb(true)
end)

-- NUI Callback for "openMap" action (triggered from NUI to open the in-game map)
RegisterNUICallback("openMap", function(data, cb)
    closePauseMenuNUI()
    isFrontendMenuOpen = true
    frontendMenuCloseTime = GetGameTimer() + 300000 -- Allow map to be open for 5 minutes (300,000 ms)
    SetFrontendActive(true)
    -- Hash -1171018317 is for "FE_MENU_VERSION_MP_PAUSE", which opens the map in FiveM
    ActivateFrontendMenu(-1171018317, false, -1)
    cb(true)
end)

-- NUI Callback for "openSettings" action (triggered from NUI to open in-game settings)
RegisterNUICallback("openSettings", function(data, cb)
    closePauseMenuNUI()
    isFrontendMenuOpen = true
    frontendMenuCloseTime = GetGameTimer() + 300000 -- Allow settings to be open for 5 minutes
    Wait(150) -- Small delay before opening frontend menu for smoother transition
    SetFrontendActive(true)
    -- Hash for "FE_MENU_VERSION_LANDING_MENU" opens the settings menu
    ActivateFrontendMenu(GetHashKey("FE_MENU_VERSION_LANDING_MENU"), false, -1)
    cb(true)
end)

-- Thread to manage frontend menu state and cooldown logic
CreateThread(function()
    local wasPauseMenuActiveLastTick = false
    while true do
        local isPauseMenuActiveCurrentTick = IsPauseMenuActive()

        -- Detect if a FiveM frontend menu (like map/settings) was active and has now closed
        if isFrontendMenuOpen and wasPauseMenuActiveLastTick and not isPauseMenuActiveCurrentTick then
            isFrontendMenuOpen = false
            -- Set a short cooldown for NUI opening to prevent immediate re-opening conflicts
            nuiCoolDownEndTime = GetGameTimer() + 400
        end

        -- If a frontend menu is currently open, check if its allowed time has passed
        if isFrontendMenuOpen then
            if GetGameTimer() > frontendMenuCloseTime then
                isFrontendMenuOpen = false
            end
        end

        wasPauseMenuActiveLastTick = isPauseMenuActiveCurrentTick
        Wait(50) -- Check every 50ms
    end
end)

-- Thread to continuously disable specific control actions (like the default pause menu and map)
CreateThread(function()
    while true do
        -- Disable default pause menu (ESC key actions)
        DisableControlAction(0, 200, true) -- INPUT_FRONTEND_PAUSE
        DisableControlAction(0, 199, true) -- INPUT_FRONTEND_PAUSE_ALTERNATE
        -- Disable default map (M key action)
        DisableControlAction(0, 322, true) -- INPUT_MAP
        Wait(0) -- Yield control for the next frame
    end
end)
local isFeatureEnabled = true -- A flag to enable some functionality
    -- Call an initial setup function from a previous part, passing arguments
    -- and the 'isFeatureEnabled' flag.
    initialSetupFunction(firstArgument, secondArgument, isFeatureEnabled)

    -- Assign a condition variable from a previous part to the initial setup function variable.
    -- This variable (originally L0_2) is heavily reused for temporary values.
    initialSetupFunction = customPauseMenuCondition

    -- If the custom pause menu condition is false or nil:
    if not initialSetupFunction then
      -- Check if the game's pause menu is currently active.
      if IsPauseMenuActive() then
        -- If it is, deactivate it.
        SetPauseMenuActive(false)
      end
    end

    Wait(0) -- Yield the thread for a minimal amount of time.
  end
end

-- Call a function with an argument, both from a previous part.
-- This might be an initial cleanup or setup, e.g., removing an old event handler.
previousEventHandler(previousEventName)

-- Reassign the 'previousEventHandler' variable (originally L9_1) to the AddEventHandler function.
previousEventHandler = AddEventHandler
-- Reassign the 'previousEventName' variable (originally L10_1) to the "onResourceStop" event string.
previousEventName = "onResourceStop"

-- Define a function to handle the "onResourceStop" event.
local function onResourceStopHandler(stoppedResource) -- Renamed L11_1 and A0_2
  local currentResource = GetCurrentResourceName() -- Renamed local L1_2
  -- If the stopped resource is not the current resource, exit the handler.
  if stoppedResource ~= currentResource then
    return
  end
  -- Get the resource's cleanup function (originally L8_1) from a previous part and execute it.
  local cleanupFunction = resourceCleanupFunction
  cleanupFunction()
end

-- Register the onResourceStop handler using the reassigned variables.
previousEventHandler(previousEventName, onResourceStopHandler)
