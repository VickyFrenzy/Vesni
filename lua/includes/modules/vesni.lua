AddCSLuaFile()
AddCSLuaFile("derma/vesni.lua")

module("vesni", package.seeall)

CreateConVar("vesni_debug", 0, FCVAR_REPLICATED + FCVAR_SERVER_CAN_EXECUTE)
local mCvarURL = CreateConVar("vesni_ui_url", "https://vesni-example.vickyfrenzy.net/", FCVAR_REPLICATED + FCVAR_SERVER_CAN_EXECUTE)

if SERVER then return end

include("derma/vesni.lua")

function alive()
	return IsValid(VesniUI)
end

function destroy()
	if not alive() then return end
	VesniUI:Close()
end
concommand.Add("vesni_ui_reload", destroy)

function focus()
	if not alive() then return end
	VesniUI:ToggleFocus()
end
concommand.Add("vesni_ui_focus", focus)

function change_menu(aMode)
	if not alive() then return end
	VesniUI:ChangeMode(aMode)
end
concommand.Add("vesni_ui_menu", function(pPlayer, _, tArgs)
	if not pPlayer:IsSuperAdmin() then return end
	change_menu(tArgs[1])
end)

local pLocalPlayer, pObserverTarget
function getPly()
	return pObserverTarget or pLocalPlayer
end

local function UI()
	if alive() then return end
	VesniUI = vgui.Create("VesniUI")
	VesniUI:OpenURL(mCvarURL:GetString())
	hook.Run("VesniUI_Created", VesniUI, getPly)
end

local function hudPaint()
	if not pLocalPlayer then
		local pLocal = LocalPlayer()
		if not IsValid(pLocal) then return end
		pLocalPlayer = pLocal
	end
	local pObserver = pLocalPlayer.Mns and pLocalPlayer:Mns().spectatingEnt or pLocalPlayer:GetObserverTarget()
	if IsValid(pObserver) and pObserver:IsPlayer() and pObserverTarget ~= pObserver then
		pObserverTarget = pObserver
	elseif pObserverTarget ~= nil then
		pObserverTarget = nil
	end
	UI()
end

function start()
	if alive() then destroy() end
	hook.Add("HUDPaint", "Vesni_HUDPaint", hudPaint)
end
concommand.Add("vesni_ui_start", function(pPlayer, _, tArgs)
	if not pPlayer:IsSuperAdmin() then return end
	start(tArgs[1])
end)

function stop()
	hook.Remove("HUDPaint", "Vesni_HUDPaint")
	destroy()
end
concommand.Add("vesni_ui_stop", function(pPlayer)
	if not pPlayer:IsSuperAdmin() then return end
	stop()
end)

hook.Add("PlayerStartVoice", "Vesni_PlayerStartVoice", function(pPly)
	pPly.Vesni_bIsTalking = true
end)

hook.Add("PlayerEndVoice", "Vesni_PlayerEndVoice", function(pPly)
	pPly.Vesni_bIsTalking = false
end)

cvars.AddChangeCallback("vesni_ui_url", function()
	destroy()
end)
