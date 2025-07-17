local HTML = {}

local tBindsRef = {
	"+forward",
	"+moveleft",
	"+moveright",
	"+back",
}

local function debug_print(...)
	local mConvar = GetConVar("vesni_debug")
	if not mConvar or not mConvar:GetBool() then return end
	MsgC(Color(255, 160, 255), "[Vesni] ")
	print(...)
	--file.Append("vesni_debug_ui.txt", table.concat({...}, "\t") .. "\n")
end

local function generateBindsTable()
	local tBinds = {}
	for _, sBind in ipairs(tBindsRef) do
		local sKey = input.LookupBinding(sBind)
		tBinds[sBind] = {
			code = input.GetKeyCode(sKey),
			key = sKey,
		}
	end
	return tBinds
end

function HTML:Init()
	self.tWatch = {}
	local mParent = self:GetParent()
	self:AddFunction("vesni", "validate", function()
		self.bValid = true
		--debug_print(SysTime(), "DocumentValidated")
	end)
	self:AddFunction("vesni", "ready", function()
		self.bReady = true
		self:Update("Binds", generateBindsTable())
		--debug_print(SysTime(), "DocumentReady")
	end)
	self:AddFunction("vesni", "action", function(sType, ...)
		debug_print("Action", sType, ...)
		if isfunction(mParent[sType]) then
			mParent[sType](mParent, ...)
		elseif isfunction(vesni[sType]) then
			vesni[sType](...)
		elseif sType == "guiOpenURL" then
			gui.OpenURL(...)
		end
	end)
	self:AddFunction("vesni", "concommand", function(sCommand, ...)
		RunConsoleCommand(sCommand, ...)
	end)
	self:AddFunction("vesni", "openurl", function(sType, sURL)
		gui.OpenURL(sURL)
	end)
	self:AddFunction("vesni", "run", function(sLua)
		RunString(sLua, "vesni.run")
	end)
	local mConvar = GetConVar("vesni_debug")
	self.bDebug = mConvar and mConvar:GetBool()
end

local tTypeHandler = {
	any = function(aValue) return "\"" .. tostring(aValue) .. "\"" end,
	boolean = function(aValue) return tostring(aValue) end,
	string = function(aValue) return "\"" .. aValue .. "\"" end,
	number = function(aValue) return aValue end,
	table = function(aValue) return util.TableToJSON(aValue) end,
	Vector = function(aValue) return table.concat(aValue:ToTable(), ",") end,
	Angle = function(aValue) return table.concat(aValue:ToTable(), ",") end,
}

local function formatArgsForJs(...)
	local sArgs = ""
	local tArgs = {...}
	for i, aArg in ipairs(tArgs) do
		if i > 1 then sArgs = sArgs .. "," end
		sArgs = sArgs .. (tTypeHandler[type(aArg)] or tTypeHandler.any)(aArg)
	end
	return sArgs
end

function HTML:jscall(sFunc, ...)
	local sArgs = formatArgsForJs(...)
	local sPayload = sFunc .. "(" .. sArgs .. ")"
	debug_print("jscall", sPayload)
	self:QueueJavascript(sPayload)
	return self
end

function HTML:Update(sType, ...)
	return self:jscall("update", sType, ...)
end

function HTML:UpdateValues()
	if not self.bReady then return end

	for _, tWatch in ipairs(self.tWatch) do
		local sName, fValue, aLastVal = tWatch.name, tWatch.func, tWatch.last
		local aVal = fValue(unpack(tWatch.args))
		if aVal == aLastVal then continue end
		tWatch.last = aVal
		self:Update(sName, aVal)
	end
end

function HTML:Think()
	if self:IsLoading() then return end

	self:UpdateValues()

	if not self.JS or not self.bReady then return end

	for _, sJS in ipairs(self.JS) do
		self:RunJavascript(sJS)
	end

	self.JS = nil
end

function HTML:AddValueToUpdate(sName, fValue, ...)
	self.tWatch[#self.tWatch + 1] = {
		name = sName,
		func = fValue,
		args = {...},
	}
	return self
end

function HTML:OnBeginLoadingDocument(sURL)
	--debug_print(SysTime(), "OnBeginLoadingDocument", sURL)
end

function HTML:OnDocumentReady(sURL)
	--debug_print(SysTime(), "OnDocumentReady", sURL)
	if not self.bDebug then return end
	self:Eruda()
end

function HTML:OnFinishLoadingDocument(sURL)
	--debug_print(SysTime(), "OnFinishLoadingDocument", sURL)
	if self.bValid then return end
	timer.Simple(6, function()
		if not IsValid(self) then return end
		self:QueueJavascript("location.reload();")
	end)
end

function HTML:OnChildViewCreated(sSourceURL, sTargetURL, bIsPopup)
	--debug_print(SysTime(), "OnChildViewCreated", sSourceURL, sTargetURL, bIsPopup)
end

function HTML:OnChangeTitle(sTitle)
end

function HTML:OnChangeTargetURL(sURL)
	--debug_print(SysTime(), "OnChangeTargetURL", sURL)
end

function HTML:Eruda()
	return self:QueueJavascript[[javascript:(function () { var script = document.createElement('script'); script.src="https://cdn.jsdelivr.net/npm/eruda"; document.body.append(script); script.onload = function () { eruda.init(); } })();]]
end

function HTML:ConsoleMessage(sMsg, sFile, line)
	if not isstring(sMsg) then sMsg = "*js variable*" end

	if not self.bDebug then return end

	MsgC(Color(255, 160, 255), "[Vesni] ")
	MsgC(Color(255, 255, 255), sMsg, "\n")
end

vgui.Register("VesniHTML", HTML, "DHTML")

local HTML_PANEL = {}

function HTML_PANEL:Init()
	self.tDraws = {}
	self.tDrawAreas = {}
	self.tBindsActions = {}
	self:SetTitle("")
	self:SetDraggable(false)
	self:ShowCloseButton(false)
	self:MakePopup()
	self.HTML = vgui.Create("VesniHTML", self)
	self.HTML:SetPos(0, 0)
	self.HTML:SetSize(ScrW(), ScrH())

	local bIsChromium = self.HTML:IsLoading() -- This returns true with Chromium but false with Awesomium https://wiki.facepunch.com/gmod/Panel:IsLoading

	if BRANCH == "chromium" or BRANCH == "x86-64" or bIsChromium then return end
	ErrorNoHalt("You are not on the x86-64 branch!\n")

	self.bNotChromium = true

	self.WARN = vgui.Create("RichText", self)
	function self.WARN:PerformLayout()
		self:SetFontInternal("DermaLarge")
		self:SetBGColor(Color(0, 0, 0))
	end
	self.WARN:Dock(FILL)
	self.WARN:SetVerticalScrollbarEnabled(false)
	self.WARN:AppendText("\n")
	local mLang = GetConVar("gmod_language")
	if mLang:GetString() == "fr" then
		self.WARN:InsertColorChange(255, 0, 0, 255)
		self.WARN:AppendText("Cette version de Garry's Mod n'est pas compatible avec Vesni !\n")
		self.WARN:AppendText("Vous devez passer sur la branche Garry's Mod \"")
		self.WARN:InsertColorChange(255, 255, 255, 255)
		self.WARN:AppendText("x86-64")
		self.WARN:InsertColorChange(255, 0, 0, 255)
		self.WARN:AppendText("\" !\n\n")
		self.WARN:InsertColorChange(255, 255, 255, 255)
		self.WARN:AppendText("Pour passer sur cette branche :\n")
		self.WARN:AppendText("- Aller dans les \"Propriétés\" de Garry's Mod sur Steam\n")
		self.WARN:AppendText("- Aller dans la section \"Bêtas\"\n")
		self.WARN:AppendText("- Dans \"Programmes de test bêta\" choisir \"x86-64 - Chromium + 64-bit binaries\"\n")
	else
		self.WARN:InsertColorChange(255, 0, 0, 255)
		self.WARN:AppendText("This version of Garry's Mod is not compatible with Vesni!\n")
		self.WARN:AppendText("You need to switch to the \"")
		self.WARN:InsertColorChange(255, 255, 255, 255)
		self.WARN:AppendText("x86-64")
		self.WARN:InsertColorChange(255, 0, 0, 255)
		self.WARN:AppendText("\" Garry's Mod branch !\n\n")
		self.WARN:InsertColorChange(255, 255, 255, 255)
		self.WARN:AppendText("To switch to this branch :\n")
		self.WARN:AppendText("- Go to Garry's Mod properties on Steam\n")
		self.WARN:AppendText("- Go to the Betas tab\n")
		self.WARN:AppendText("- In Beta Participation select x86-64 - Chromium + 64-bit binaries\n")
	end
end

function HTML_PANEL:GetModelPanel(aIdentifier)
	local mModelPanel = self.tDraws[aIdentifier]
	if not IsValid(mModelPanel) then return nil end
	return mModelPanel
end

function HTML_PANEL:_ModelUpdateHTML(aIdentifier)
	local t = {}
	local mModelPanel = self:GetModelPanel(aIdentifier)
	local eEnt = mModelPanel:GetEntity()
	local iSkins = eEnt:SkinCount()
	t.skin = iSkins
	local tBodygroups = eEnt:GetBodyGroups()
	for _, tBodyGroup in ipairs(tBodygroups) do
		t[tBodyGroup.name] = {
			id = tBodyGroup.id,
			values = tBodyGroup.num,
		}
	end
	self:Update("modelInfo", aIdentifier, t)
	return self
end

local function _extraUpdate(mModelPanel, tExtra, bLocalPlayer)
	local iSkin, sBodygroups, iFOV, nScale, iZPos
	if tExtra then
		iSkin, sBodygroups, iFOV, nScale, iZPos = tExtra.skin, tExtra.bodygroups, tExtra.fov, tExtra.scale, tExtra.zpos
	end

	if iFOV then mModelPanel:SetFOV(iFOV) end

	if iZPos then mModelPanel:SetZPos(iZPos) end

	local eEnt = mModelPanel:GetEntity()

	if sBodygroups then eEnt:SetBodyGroups(sBodygroups) end

	if bLocalPlayer then
		local pLocalPlayer = LocalPlayer()

		iSkin = pLocalPlayer:GetSkin()

		local iBodyGroups = #pLocalPlayer:GetBodyGroups()
		for i = 0, iBodyGroups - 1 do
			eEnt:SetBodygroup(i, pLocalPlayer:GetBodygroup(i))
		end

		nScale = pLocalPlayer:GetModelScale()
	end

	if iSkin then eEnt:SetSkin(iSkin) end

	if nScale then eEnt:SetModelScale(nScale) end
end

function HTML_PANEL:AddModelPanel(aIdentifier, sModel, x, y, size_w, size_h, tExtra)
	if IsValid(self.tDraws[aIdentifier]) then
		return self:UpdateModelPanel(aIdentifier, sModel, x, y, size_w, size_h, tExtra)
	end
	local mModelPanel = vgui.Create("VesniModelPanel", self)
	self.tDraws[aIdentifier] = mModelPanel
	mModelPanel:SetKeyboardInputEnabled(false)
	mModelPanel:SetMouseInputEnabled(false)
	mModelPanel:SetZPos(128)
	mModelPanel:SetPos(x or 0, y or 0)
	mModelPanel:SetSize(size_w or 200, size_h or 200)
	local bLocalPlayer = sModel == "LocalPlayer"
	mModelPanel:SetModel(bLocalPlayer and LocalPlayer():GetModel() or sModel or "models/error.mdl")
	mModelPanel:SetAnimated(true)
	--self:_ModelUpdateHTML(aIdentifier)
	_extraUpdate(mModelPanel, tExtra, bLocalPlayer)
	return mModelPanel
end

function HTML_PANEL:AddPlayerModelPanel(aIdentifier, sModel, ...)
	sModel = sModel == "LocalPlayer" and sModel or player_manager.TranslatePlayerModel(sModel)
	return self:AddModelPanel(aIdentifier, sModel, ...)
end

function HTML_PANEL:UpdateModelPanel(aIdentifier, sModel, x, y, size_w, size_h, tExtra)
	local mModelPanel = self:GetModelPanel(aIdentifier)
	if not mModelPanel then
		return self:AddModelPanel(aIdentifier, sModel, x, y, size_w, size_h, tExtra)
	end
	local bLocalPlayer = sModel == "LocalPlayer"
	local last_x, last_y = mModelPanel:GetPos()
	mModelPanel:SetPos(x or last_x or 0, y or last_y or 0)
	local last_w, last_h = mModelPanel:GetSize()
	mModelPanel:SetSize(size_w or last_w or 200, size_h or last_h or 200)
	if sModel then
		sModel = bLocalPlayer and LocalPlayer():GetModel() or sModel
		if sModel ~= mModelPanel:GetModel() then mModelPanel:SetModel(sModel) end
	end
	mModelPanel:SetVisible(true)
	--self:_ModelUpdateHTML(aIdentifier)
	_extraUpdate(mModelPanel, tExtra, bLocalPlayer)
	return mModelPanel
end

function HTML_PANEL:UpdatePlayerModelPanel(aIdentifier, sModel, ...)
	sModel = sModel == "LocalPlayer" and sModel or player_manager.TranslatePlayerModel(sModel)
	return self:UpdateModelPanel(aIdentifier, sModel, ...)
end

function HTML_PANEL:ShowModelPanel(aIdentifier)
	local mModelPanel = self:GetModelPanel(aIdentifier)
	if not mModelPanel then return nil end
	mModelPanel:SetVisible(true)
	return mModelPanel
end

function HTML_PANEL:HideModelPanel(aIdentifier)
	local mModelPanel = self:GetModelPanel(aIdentifier)
	if not mModelPanel then return nil end
	mModelPanel:SetVisible(false)
	return mModelPanel
end

function HTML_PANEL:RunModelPanelAnimation(aIdentifier, sAnimation, bOnce)
	local mModelPanel = self:GetModelPanel(aIdentifier)
	if not mModelPanel then return nil end

	local eEnt = mModelPanel:GetEntity()
	local nSequence, nDuration = eEnt:LookupSequence(sAnimation or "idle_all_01")

	if nSequence < 0 or nDuration == 0 then return mModelPanel end

	eEnt:SetSequence(nSequence)

	if not bOnce then return mModelPanel end

	timer.Simple(nDuration, function()
		if not IsValid(self) then return end
		self:RunModelPanelAnimation(aIdentifier, "idle_all_01")
	end)

	return mModelPanel
end

function HTML_PANEL:RemoveModelPanel(aIdentifier)
	local mModelPanel = self.tDraws[aIdentifier]
	if not mModelPanel then return self end
	self.tDraws[aIdentifier] = nil
	if IsValid(mModelPanel) then
		mModelPanel:Remove()
	end
	return self
end

function HTML_PANEL:RemoveAllModelPanels()
	for _, mModelPanel in pairs(self.tDraws) do
		if not IsValid(mModelPanel) then continue end
		mModelPanel:Remove()
	end
	self.tDraws = {}
	return self
end

function HTML_PANEL:Focus(aMode)
	self:SetZPos(64)
	self:SetKeyboardInputEnabled(true)
	self:SetMouseInputEnabled(true)
	self.bFocus = true
	self.iStartTime = SysTime()
	self.iMode = aMode or self.iMode
	return self
end

function HTML_PANEL:UnFocus(aMode)
	self:SetZPos(-32768)
	self:SetKeyboardInputEnabled(false)
	self:SetMouseInputEnabled(false)
	self.bFocus = false
	self.iStartTime = SysTime()
	self.iMode = aMode or self.iMode
	return self
end

function HTML_PANEL:jscall(...)
	if not self.HTML or not IsValid(self.HTML) then return self end
	self.HTML:jscall(...)
	return self.HTML
end

function HTML_PANEL:Update(...)
	if not self.HTML or not IsValid(self.HTML) then return self end
	self.HTML:Update(...)
	return self.HTML
end

function HTML_PANEL:HUD()
	self:Update("mode", 0)
	return self:UnFocus(0)
end

function HTML_PANEL:ChangeMode(aMode)
	self:Update("mode", aMode)
	return self:Focus(aMode)
end

function HTML_PANEL:ToggleFocus()
	return self.bFocus and self:HUD() or self:Focus()
end

function HTML_PANEL:ToggleMode()
	if (self.iMode or 0) == 0 then return self:ChangeMode(1) end
	return self:HUD()
end

function HTML_PANEL:OpenURL(...)
	if not self.HTML or not IsValid(self.HTML) then return self end
	self.HTML:OpenURL(...)
	return self.HTML
end

function HTML_PANEL:AddValueToUpdate(...)
	if not self.HTML or not IsValid(self.HTML) then return self end
	self.HTML:AddValueToUpdate(...)
	return self.HTML
end

function HTML_PANEL:DrawBackground(...)
	self.tBackgroundColor = {...}
end

function HTML_PANEL:RemoveBackground()
	self.tBackgroundColor = nil
end

function HTML_PANEL:DrawArea(id, ...)
	self.tDrawAreas[id] = {...}
end

function HTML_PANEL:RemoveArea(id)
	self.tDrawAreas[id] = nil
end

function HTML_PANEL:Setup()
end

function HTML_PANEL:OnRemove()
end

function HTML_PANEL:PaintAreas(w, h)
	if #self.tDrawAreas == 0 then return end
	for _, tArea in ipairs(self.tDrawAreas) do
		draw.RoundedBox(unpack(tArea))
	end
end

function HTML_PANEL:PaintBackground(w, h)
	if not self.tBackgroundColor then return end
	local r, g, b, a = unpack(self.tBackgroundColor)
	local iFraction = math.Clamp((SysTime() - self.iStartTime) / 1, 0, 1)
	surface.SetDrawColor(r, g, b, a * iFraction)
	surface.DrawRect(0, 0, w, h)
end

function HTML_PANEL:Paint(w, h)
	self:PaintBackground(w, h)
	self:PaintAreas(w, h)
end

function HTML_PANEL:AddBindAction(iMode, sBind, sAction, ...)
	if not iMode then iMode = 0 end
	if not self.tBindsActions[iMode] then self.tBindsActions[iMode] = {} end
	table.insert(self.tBindsActions[iMode], {
		code = input.GetKeyCode(input.LookupBinding(sBind)),
		action = sAction,
		arguments = {...},
	})
	return self
end

function HTML_PANEL:OnKeyCodeReleased(ikeyCode)
	local iMode = self.iMode or 0
	if not self.tBindsActions[iMode] then return end
	for _, v in ipairs(self.tBindsActions[iMode]) do
		if ikeyCode ~= v.code then continue end
		self[v.action](self, unpack(v.arguments))
		break
	end
end

vgui.Register("VesniHTMLPanel", HTML_PANEL, "DFrame")

local VesniUI = {}

VesniUI.BaseInit = HTML_PANEL.Init

function VesniUI:Init()
	self:ParentToHUD()
	self:SetPos(0, 0)
	self:SetSize(ScrW(), ScrH())
	self:SetScreenLock(true)
	self:BaseInit()
	self:UnFocus(0)
end

VesniUI.BasePaint = HTML_PANEL.Paint

function VesniUI:Paint(w, h)
	if (self.iMode or 0) ~= 0 then
		Derma_DrawBackgroundBlur(self, self.iStartTime)
	end
	self:BasePaint(w, h)
end

vgui.Register("VesniUI", VesniUI, "VesniHTMLPanel")

VesniModelPanel = {}

function VesniModelPanel:LayoutEntity(Entity)
	if self.bAnimated then self:RunAnimation() end
end

vgui.Register("VesniModelPanel", VesniModelPanel, "DModelPanel")
