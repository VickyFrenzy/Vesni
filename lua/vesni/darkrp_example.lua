-- Welcome to an example of Vesni for DarkRP!

require("vesni")

if SERVER then return end

local tModes = {
	HUD = 0,
	INVENTORY = 1,
}

local sInvBind = "gm_showteam"
hook.Add("PlayerBindPress", "Vesni_PlayerBindPress", function(pLocalPlayer, sBind, bPressed, iCode)
	if bPressed and sBind == sInvBind then
		if not IsValid(vesni.VesniUI) then return end
		vesni.VesniUI:ToggleMode()
	end
end)

hook.Add("VesniUI_Created", "VesniUI_Created", function(VesniUI, getPly) -- You can add anything you want to watch and automatically send to the webpage.
	VesniUI:AddValueToUpdate("MonoSuiteLoaded", function() return MonoSuite and MonoSuite.IsLoaded() end)
	:AddValueToUpdate("DrawHUD", function() return GetConVar("cl_drawhud"):GetBool() end)
	:AddValueToUpdate("Name", function() return getPly().getDarkRPVar and getPly():getDarkRPVar("rpname") or getPly():Nick() end)
	:AddValueToUpdate("Job", function() return getPly().getJobTable and getPly():getJobTable() or nil end)
	:AddValueToUpdate("SteamName", function() return getPly().SteamName and getPly():SteamName() end)
	:AddValueToUpdate("SteamID", function() return getPly():SteamID64() end)
	:AddValueToUpdate("Health", function() return getPly():Health() end)
	:AddValueToUpdate("Armor", function() return getPly():Armor() end)
	:AddValueToUpdate("Hunger", function() return getPly().getDarkRPVar and getPly():getDarkRPVar("Energy") or nil end)
	:AddValueToUpdate("Money", function() return getPly().getDarkRPVar and getPly():getDarkRPVar("money") or nil end)
	:AddValueToUpdate("IsTalking", function() return getPly().Vesni_bIsTalking end)
	if EVoice then
		VesniUI:AddValueToUpdate("VoiceMode", function() return getPly().GetVoiceMode and getPly():GetVoiceMode() end)
		:AddValueToUpdate("RadioEnabled", function() return getPly().GetRadioEnabled and getPly():GetRadioEnabled() end)
		:AddValueToUpdate("RadioSound", function() return getPly().GetRadioSound and getPly():GetRadioSound() end)
		:AddValueToUpdate("RadioMic", function() return getPly().GetRadioMic and getPly():GetRadioMic() end)
		:AddValueToUpdate("RadioFrequency", function() return getPly().GetRadioFrequency and getPly():GetRadioFrequency() end)
	end
	VesniUI:AddBindAction(tModes.INVENTORY, sInvBind, "ToggleMode") -- You can bind actions in specified modes.
end)

local hideHUDElements = {
	["CHudDamageIndicator"] = true,
	["DarkRP_HUD"] = false,
	["DarkRP_EntityDisplay"] = false,
	["DarkRP_LocalPlayerHUD"] = true,
	["DarkRP_Hungermod"] = true,
	["DarkRP_Agenda"] = false,
	["DarkRP_LockdownHUD"] = false,
	["DarkRP_ArrestedHUD"] = false,
	["DarkRP_ChatReceivers"] = false,
	["DarkRP_VoiceChat"] = true,
}

hook.Add("HUDShouldDraw", "HideDefaultDarkRPHud", function(name)
	if IsValid(VesniUI) and hideHUDElements[name] then return false end
end)

vesni.start()
