require "Window"
 
local ForgeUI
local ForgeUI_CastBars = {} 
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function ForgeUI_CastBars:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- mandatory 
    self.api_version = 2
	self.version = "1.0.0"
	self.author = "WintyBadass"
	self.strAddonName = "ForgeUI_CastBars"
	self.strDisplayName = "Cast bars"
	
	self.wndContainers = {}
	
	self.tStylers = {
		["UpdateStyle_PlayerCastBar"] = self,
		["RefreshStyle_PlayerCastBar"] = self, -- (unitPlayer, wnd)
		["UpdateStyle_TargetCastBar"] = self,
		["RefreshStyle_TargetCastBar"] = self, -- (unitTarget, wnd)
		["UpdateStyle_FocusCastBar"] = self,
		["RefreshStyle_FocusCastBar"] = self, -- (unitFocus, wnd)
	}
	
	-- optional
	self.settings_version = 1
	self.tSettings = {
		bSmoothBars = true,
		bShowTarget = true,
		bShowFocus = true,
		bCenterPlayerText = false,
		bCenterTargetText = false,
		bCenterFocusText = false,
		bShowCastIcons = true,
		crBorder = "FF000000",
		crBackground = "FF101010",
		crCastBar = "FF272727",
		crCastBarTarget = "FF272727",
		crInfArmorTarget = "FFEA0707",
		crCastBarFocus = "FF272727",
		crInfArmorFocus = "FFEA0707",
		crMooBar = "FFBC00BB",
		crDuration = "FFFFCC00",
		crText = "FFFFFFFF"
	}
	
	self.cast = nil

    return o
end

function ForgeUI_CastBars:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		"ForgeUI"
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 
function ForgeUI_CastBars:ForgeAPI_AfterRegistration()
	ForgeUI.API_AddItemButton(self, "Cast bars", { strContainer = "Container" })
	
	self.wndPlayerCastBar = Apollo.LoadForm(self.xmlDoc, "PlayerCastBar", "FixedHudStratum", self)
	self.wndTargetCastBar = Apollo.LoadForm(self.xmlDoc, "TargetCastBar", "FixedHudStratum", self)
	self.wndFocusCastBar = Apollo.LoadForm(self.xmlDoc, "FocusCastBar", "FixedHudStratum", self)
	
	ForgeUI.API_RegisterWindow(self, self.wndPlayerCastBar, "ForgeUI_PlayerCastBar", { strDisplayName = "Player cast bar" })
	ForgeUI.API_RegisterWindow(self, self.wndTargetCastBar, "ForgeUI_TargetCastBar", { strDisplayName = "Target cast bar" })
	ForgeUI.API_RegisterWindow(self, self.wndTargetCastBar:FindChild("InterruptArmor"), "ForgeUI_TargetCastBar_IA", { strDisplayName = "IA", strParent = "ForgeUI_TargetCastBar", bMaintainRatio = true })
	ForgeUI.API_RegisterWindow(self, self.wndFocusCastBar, "ForgeUI_FocusCastBar", { strDisplayName = "Focus cast bar" })
	ForgeUI.API_RegisterWindow(self, self.wndFocusCastBar:FindChild("InterruptArmor"), "ForgeUI_FocusCastBar_IA", { strDisplayName = "IA", strParent = "ForgeUI_FocusCastBar", bMaintainRatio = true })
end

function ForgeUI_CastBars:OnNextFrame()
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil or not unitPlayer:IsValid() then return end

	self:UpdateCastBar(unitPlayer, self.wndPlayerCastBar)
	self.tStylers["RefreshStyle_PlayerCastBar"]["RefreshStyle_PlayerCastBar"](self, unitPlayer, self.wndPlayerCastBar)
	
	local unitTarget = unitPlayer:GetTarget()
	if unitTarget ~= nil and unitTarget:IsValid() and self.tSettings.bShowTarget then
		self:UpdateCastBar(unitTarget, self.wndTargetCastBar)
		self:UpdateMoOBar(unitTarget, self.wndTargetCastBar)
		self:UpdateInterruptArmor(unitTarget, self.wndTargetCastBar)
		
		self.tStylers["RefreshStyle_TargetCastBar"]["RefreshStyle_TargetCastBar"](self, unitTarget, self.wndTargetCastBar)
	else	
		if self.wndTargetCastBar:IsShown() then
			self.wndTargetCastBar:Show(false, true)
		end
	end
	
	local unitFocus = unitPlayer:GetAlternateTarget()
	if unitFocus ~= nil and unitFocus:IsValid() and self.tSettings.bShowFocus then
		self:UpdateCastBar(unitFocus, self.wndFocusCastBar)
		self:UpdateMoOBar(unitFocus, self.wndFocusCastBar)
		self:UpdateInterruptArmor(unitFocus, self.wndFocusCastBar)
		
		self.tStylers["RefreshStyle_FocusCastBar"]["RefreshStyle_FocusCastBar"](self, unitFocus, self.wndFocusCastBar)
	else	
		if self.wndFocusCastBar:IsShown() then
			self.wndFocusCastBar:Show(false, true)
		end
	end
	
	if self.cast ~= nil then
		local fTimeLeft = 1-GameLib.GetSpellThresholdTimePrcntDone(self.cast.id)
		self.wndPlayerCastBar:FindChild("DurationBar"):SetProgress(fTimeLeft)
	else
		self.wndPlayerCastBar:FindChild("DurationBar"):SetProgress(0)
	end
end

function ForgeUI_CastBars:OnStartSpellThreshold(idSpell, nMaxThresholds, eCastMethod)
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil or not unitPlayer:IsValid() then return end
	
	local splObject = GameLib.GetSpell(idSpell)
	
	if self.cast == nil then
		self.cast = {}
		self.cast.id = idSpell
		self.cast.strSpellName = splObject:GetName()
		self.cast.nThreshold = 1
		self.cast.nMaxThreshold = nMaxThresholds
		
		self.wndPlayerCastBar:FindChild("SpellName"):SetText(self.cast.strSpellName)
		self.wndPlayerCastBar:FindChild("TickBar"):SetMax(nMaxThresholds)
		self.wndPlayerCastBar:FindChild("TickBar"):SetProgress(self.cast.nMaxThreshold - self.cast.nThreshold)
		self.wndPlayerCastBar:FindChild("CastTime"):SetText(self.cast.nThreshold)
		
		self.wndPlayerCastBar:Show(true, true)
	end
end

function ForgeUI_CastBars:OnUpdateSpellThreshold(idSpell, nNewThreshold)
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil or not unitPlayer:IsValid() or self.cast == nil then return end
	
	local splObject = GameLib.GetSpell(idSpell)
	local strSpellName = splObject:GetName()
	
	self.cast.nThreshold = nNewThreshold
	
	self.wndPlayerCastBar:FindChild("SpellName"):SetText(strSpellName)
	self.wndPlayerCastBar:FindChild("TickBar"):SetProgress(self.cast.nMaxThreshold - nNewThreshold)
	
	self.wndPlayerCastBar:FindChild("TickBar"):SetProgress(self.cast.nMaxThreshold - nNewThreshold)
	
	self.wndPlayerCastBar:FindChild("CastTime"):SetText(nNewThreshold)
end

function ForgeUI_CastBars:OnClearSpellThreshold(idSpell)
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil or not unitPlayer:IsValid() or self.cast == nil then return end
	
	self.wndPlayerCastBar:Show(false, true)
	self.wndPlayerCastBar:FindChild("TickBar"):SetProgress(0)
	
	self.cast = nil
end

function ForgeUI_CastBars:UpdateCastBar(unit, wnd)
	if unit == nil or wnd == nil or unit:IsDead() then return end
	
	local fDuration
	local fElapsed
	local strSpellName
	local bShowCast = false
	local bShowTick = false
	
	if unit:ShouldShowCastBar() then
		bShowCast = true
		
		fDuration = unit:GetCastDuration()
		fElapsed = unit:GetCastElapsed()	
		strSpellName = unit:GetCastName()
		
		wnd:FindChild("SpellName"):SetText(strSpellName)
		wnd:FindChild("CastBar"):SetMax(fDuration)
		wnd:FindChild("CastBar"):SetProgress(fElapsed)
		if wnd:FindChild("Icon") then
			local strIcon = self:GetSpellIconByName(strSpellName)
			if strIcon ~= "" and self.tSettings.bShowCastIcons then
				wnd:FindChild("Icon"):SetSprite(self:GetSpellIconByName(strSpellName))
				wnd:FindChild("IconHolder"):Show(true, true)
			else
				wnd:FindChild("IconHolder"):Show(false, true)
			end
		end
		wnd:FindChild("CastTime"):SetText(string.format("%00.01f", (fDuration - fElapsed)/1000) .. "s")
	elseif wnd:GetName() ==  "PlayerCastBar" and self.cast ~= nil then
		wnd:FindChild("SpellName"):SetText(self.cast.strSpellName)
		wnd:FindChild("CastTime"):SetText(self.cast.nThreshold)
		
		local fTimeLeft = 1-GameLib.GetSpellThresholdTimePrcntDone(self.cast.id)
		self.wndPlayerCastBar:FindChild("DurationBar"):SetProgress(fTimeLeft)
		
		bShowTick = true
	end
	
	if bShowCast or bShowTick  ~= wnd:IsShown() then
		wnd:Show(bShowCast or bShowTick, true)
	end
	
	if bShowCast ~= wnd:FindChild("Cast"):IsShown() then
		wnd:FindChild("Cast"):Show(bShowCast, true)
	end
	
	if bShowTick ~= wnd:FindChild("Tick"):IsShown() then
		wnd:FindChild("Tick"):Show(bShowTick, true)
	end
end

local maxTime = 0
function ForgeUI_CastBars:UpdateMoOBar(unit, wnd)
	if unit == nil or wnd == nil or unit:IsDead() then return end
	
	local maxTime = unit:GetCCStateTotalTime(Unit.CodeEnumCCState.Vulnerability)
	local time = unit:GetCCStateTimeRemaining(Unit.CodeEnumCCState.Vulnerability)
	local pl = GameLib.GetPlayerUnit()
	
	if time > 0 then
		--maxTime = time > maxTime and time or maxTime
	
		wnd:FindChild("MoOBar"):SetMax(maxTime)
		wnd:FindChild("MoOBar"):SetProgress(time)
		
		wnd:FindChild("SpellName"):SetText("MoO")
		wnd:FindChild("CastTime"):SetText(ForgeUI.Round(time, 1))
		
		if not wnd:IsShown() then
			wnd:Show(true, true)
		end
	else
		wnd:FindChild("MoOBar"):SetProgress(0)
		maxTime = 0
	end
end

function ForgeUI_CastBars:UpdateInterruptArmor(unit, wnd)
	local bShow = false
	nValue = unit:GetInterruptArmorValue()
	nMax = unit:GetInterruptArmorMax()
	if nMax == 0 or nValue == nil or unit:IsDead() then
	else
		bShow = true
		if nMax == -1 then
			wnd:FindChild("InterruptArmor"):SetSprite("ForgeUI_IAinf")
			wnd:FindChild("InterruptArmor_Value"):SetText("")
		elseif nMax > 0 then
			wnd:FindChild("InterruptArmor"):SetSprite("ForgeUI_IA")
			wnd:FindChild("InterruptArmor_Value"):SetText(nValue)
		end
	end
	
	if bShow ~= wnd:FindChild("InterruptArmor"):IsShown() then
		wnd:FindChild("InterruptArmor"):Show(bShow, true)
	end
end

-----------------------------------------------------------------------------------------------
-- Styles
-----------------------------------------------------------------------------------------------

function ForgeUI_CastBars:UpdateStyles()
	self.tStylers["UpdateStyle_PlayerCastBar"]["UpdateStyle_PlayerCastBar"](self)
	self.tStylers["UpdateStyle_TargetCastBar"]["UpdateStyle_TargetCastBar"](self)
	self.tStylers["UpdateStyle_FocusCastBar"]["UpdateStyle_FocusCastBar"](self)
end

function ForgeUI_CastBars:UpdateStyle_PlayerCastBar()
	self.wndPlayerCastBar:FindChild("Border"):SetBGColor(self.tSettings.crBorder)
	self.wndPlayerCastBar:FindChild("Background"):SetBGColor(self.tSettings.crBackground)
	self.wndPlayerCastBar:FindChild("CastBar"):SetBarColor(self.tSettings.crCastBar)
	self.wndPlayerCastBar:FindChild("TickBar"):SetBarColor(self.tSettings.crCastBar)
	self.wndPlayerCastBar:FindChild("DurationBar"):SetBarColor(self.tSettings.crDuration)
	self.wndPlayerCastBar:FindChild("CastTime"):SetTextColor(self.tSettings.crText)
	self.wndPlayerCastBar:FindChild("SpellName"):SetTextColor(self.tSettings.crText)
	
	if self.tSettings.bCenterPlayerText then
		self.wndPlayerCastBar:FindChild("SpellName"):SetAnchorOffsets(10, 0, 0, 0)
		self.wndPlayerCastBar:FindChild("SpellName"):SetAnchorPoints(0, 0, 1, 1)
		
		self.wndPlayerCastBar:FindChild("CastTime"):SetAnchorOffsets(0, 0, -10, 0)
		self.wndPlayerCastBar:FindChild("CastTime"):SetAnchorPoints(0, 0, 1, 1)
	else
		self.wndPlayerCastBar:FindChild("SpellName"):SetAnchorOffsets(10, -10, 0, 15)
		self.wndPlayerCastBar:FindChild("SpellName"):SetAnchorPoints(0, 0, 1, 0)
		
		self.wndPlayerCastBar:FindChild("CastTime"):SetAnchorOffsets(0, -10, -10, 15)
		self.wndPlayerCastBar:FindChild("CastTime"):SetAnchorPoints(0, 0, 1, 0)
	end
end

function ForgeUI_CastBars:RefreshStyle_PlayerCastBar(unit, wnd)
end

function ForgeUI_CastBars:UpdateStyle_TargetCastBar()
	self.wndTargetCastBar:FindChild("Border"):SetBGColor(self.tSettings.crBorder)
	self.wndTargetCastBar:FindChild("IconHolder"):SetBGColor(self.tSettings.crBorder)
	self.wndTargetCastBar:FindChild("Background"):SetBGColor(self.tSettings.crBackground)
	self.wndTargetCastBar:FindChild("CastBar"):SetBarColor(self.tSettings.crCastBarTarget)
	self.wndTargetCastBar:FindChild("MoOBar"):SetBarColor(self.tSettings.crMooBar)
	self.wndTargetCastBar:FindChild("CastTime"):SetTextColor(self.tSettings.crText)
	self.wndTargetCastBar:FindChild("SpellName"):SetTextColor(self.tSettings.crText)
	
	if self.tSettings.bCenterTargetText then
		self.wndTargetCastBar:FindChild("SpellName"):SetAnchorOffsets(10, 0, 0, 0)
		self.wndTargetCastBar:FindChild("SpellName"):SetAnchorPoints(0, 0, 1, 1)
		
		self.wndTargetCastBar:FindChild("CastTime"):SetAnchorOffsets(0, 0, -10, 0)
		self.wndTargetCastBar:FindChild("CastTime"):SetAnchorPoints(0, 0, 1, 1)
	else
		self.wndTargetCastBar:FindChild("SpellName"):SetAnchorOffsets(10, -10, 0, 15)
		self.wndTargetCastBar:FindChild("SpellName"):SetAnchorPoints(0, 0, 1, 0)
		
		self.wndTargetCastBar:FindChild("CastTime"):SetAnchorOffsets(0, -10, -10, 15)
		self.wndTargetCastBar:FindChild("CastTime"):SetAnchorPoints(0, 0, 1, 0)
	end
	
	local nLeft, nTop, nRight, nBottom = self.wndTargetCastBar:GetAnchorOffsets()
	self.wndTargetCastBar:FindChild("IconHolder"):SetAnchorOffsets(nTop - nBottom - 5, 0, -5, 0)
end

function ForgeUI_CastBars:RefreshStyle_TargetCastBar(unit, wnd)
	local nMax = unit:GetInterruptArmorMax()
	if nMax == -1 then
		wnd:FindChild("CastBar"):SetBarColor(self.tSettings.crInfArmorTarget)
	else
		wnd:FindChild("CastBar"):SetBarColor(self.tSettings.crCastBarTarget)
	end
end

function ForgeUI_CastBars:UpdateStyle_FocusCastBar()
	self.wndFocusCastBar:FindChild("Border"):SetBGColor(self.tSettings.crBorder)
	self.wndFocusCastBar:FindChild("IconHolder"):SetBGColor(self.tSettings.crBorder)
	self.wndFocusCastBar:FindChild("Background"):SetBGColor(self.tSettings.crBackground)
	self.wndFocusCastBar:FindChild("CastBar"):SetBarColor(self.tSettings.crCastBarFocus)
	self.wndFocusCastBar:FindChild("MoOBar"):SetBarColor(self.tSettings.crMooBar)
	self.wndFocusCastBar:FindChild("CastTime"):SetTextColor(self.tSettings.crText)
	self.wndFocusCastBar:FindChild("SpellName"):SetTextColor(self.tSettings.crText)
	
	if self.tSettings.bCenterFocusText then
		self.wndFocusCastBar:FindChild("SpellName"):SetAnchorOffsets(10, 0, 0, 0)
		self.wndFocusCastBar:FindChild("SpellName"):SetAnchorPoints(0, 0, 1, 1)
		
		self.wndFocusCastBar:FindChild("CastTime"):SetAnchorOffsets(0, 0, -10, 0)
		self.wndFocusCastBar:FindChild("CastTime"):SetAnchorPoints(0, 0, 1, 1)
	else
		self.wndFocusCastBar:FindChild("SpellName"):SetAnchorOffsets(10, -10, 0, 15)
		self.wndFocusCastBar:FindChild("SpellName"):SetAnchorPoints(0, 0, 1, 0)
		
		self.wndFocusCastBar:FindChild("CastTime"):SetAnchorOffsets(0, -10, -10, 15)
		self.wndFocusCastBar:FindChild("CastTime"):SetAnchorPoints(0, 0, 1, 0)
	end
	
	local nLeft, nTop, nRight, nBottom = self.wndFocusCastBar:GetAnchorOffsets()
	self.wndFocusCastBar:FindChild("IconHolder"):SetAnchorOffsets(nTop - nBottom - 5, 0, -5, 0)
end

function ForgeUI_CastBars:RefreshStyle_FocusCastBar(unit, wnd)
	local nMax = unit:GetInterruptArmorMax()
	if nMax == -1 then
		wnd:FindChild("CastBar"):SetBarColor(self.tSettings.crInfArmorFocus)
	else
		wnd:FindChild("CastBar"):SetBarColor(self.tSettings.crCastBarFocus)
	end
end

function ForgeUI_CastBars:GetAbilitiesList()
	if self.abilityNameToIcon == nil then
		self.abilityNameToIcon = {}
	
		local list = AbilityBook.GetAbilitiesList()
		for _, ability in pairs(list) do
			self.abilityNameToIcon[ability.strName] = ability.tTiers[1].splObject:GetIcon()
		end
	end
	return self.abilityNameToIcon
end

function ForgeUI_CastBars:GetSpellIconByName(spellName)
	local abilities = self:GetAbilitiesList()
	
	if abilities[spellName] ~= nil then
		return abilities[spellName]
	end
	
	return ""
end

-----------------------------------------------------------------------------------------------
-- ForgeUI_CastBars OnLoad
-----------------------------------------------------------------------------------------------
function ForgeUI_CastBars:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ForgeUI_CastBars.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- ForgeUI_CastBars OnDocLoaded
-----------------------------------------------------------------------------------------------
function ForgeUI_CastBars:OnDocLoaded()
	if self.xmlDoc == nil or self.xmlDoc:IsLoaded() == false then return end
	
	if ForgeUI == nil then -- forgeui loaded
		ForgeUI = Apollo.GetAddon("ForgeUI")
	end
	
	ForgeUI.API_RegisterAddon(self)
end

function ForgeUI_CastBars:ForgeAPI_AfterRestore()
	if self.tSettings.bSmoothBars == true then
		Apollo.RegisterEventHandler("NextFrame", 	"OnNextFrame", self)
	else
		Apollo.RegisterEventHandler("VarChange_FrameCount", 	"OnNextFrame", self)
	end
	Apollo.RegisterEventHandler("StartSpellThreshold", 	"OnStartSpellThreshold", self)
	Apollo.RegisterEventHandler("ClearSpellThreshold", 	"OnClearSpellThreshold", self)
	Apollo.RegisterEventHandler("UpdateSpellThreshold", "OnUpdateSpellThreshold", self)
	
	ForgeUI.API_RegisterColorBox(self, self.wndContainers.Container:FindChild("crBorder"), self.tSettings, "crBorder", false, "UpdateStyles" )
	ForgeUI.API_RegisterColorBox(self, self.wndContainers.Container:FindChild("crBackground"), self.tSettings, "crBackground", false, "UpdateStyles" )
	ForgeUI.API_RegisterColorBox(self, self.wndContainers.Container:FindChild("crCastBar"), self.tSettings, "crCastBar", false, "UpdateStyles" )
	ForgeUI.API_RegisterColorBox(self, self.wndContainers.Container:FindChild("crCastBarTarget"), self.tSettings, "crCastBarTarget", false, "UpdateStyles" )
	ForgeUI.API_RegisterColorBox(self, self.wndContainers.Container:FindChild("crInfArmorTarget"), self.tSettings, "crInfArmorFocus", false, "UpdateStyles" )
	ForgeUI.API_RegisterColorBox(self, self.wndContainers.Container:FindChild("crCastBarFocus"), self.tSettings, "crCastBarFocus", false, "UpdateStyles" )
	ForgeUI.API_RegisterColorBox(self, self.wndContainers.Container:FindChild("crInfArmorFocus"), self.tSettings, "crInfArmorFocus", false, "UpdateStyles" )
	ForgeUI.API_RegisterColorBox(self, self.wndContainers.Container:FindChild("crMooBar"), self.tSettings, "crMooBar", false, "UpdateStyles" )
	ForgeUI.API_RegisterColorBox(self, self.wndContainers.Container:FindChild("crDuration"), self.tSettings, "crDuration", false, "UpdateStyles" )
	ForgeUI.API_RegisterColorBox(self, self.wndContainers.Container:FindChild("crText"), self.tSettings, "crText", false, "UpdateStyles" )
	
	ForgeUI.API_RegisterCheckBox(self, self.wndContainers.Container:FindChild("bSmoothBars"), self.tSettings, "bSmoothBars")
	ForgeUI.API_RegisterCheckBox(self, self.wndContainers.Container:FindChild("bCenterPlayerText"), self.tSettings, "bCenterPlayerText", "UpdateStyles")
	ForgeUI.API_RegisterCheckBox(self, self.wndContainers.Container:FindChild("bCenterTargetText"), self.tSettings, "bCenterTargetText", "UpdateStyles")
	ForgeUI.API_RegisterCheckBox(self, self.wndContainers.Container:FindChild("bCenterFocusText"), self.tSettings, "bCenterFocusText", "UpdateStyles")
	ForgeUI.API_RegisterCheckBox(self, self.wndContainers.Container:FindChild("bShowFocus"), self.tSettings, "bShowFocus")
	ForgeUI.API_RegisterCheckBox(self, self.wndContainers.Container:FindChild("bShowTarget"), self.tSettings, "bShowTarget")
	ForgeUI.API_RegisterCheckBox(self, self.wndContainers.Container:FindChild("bShowCastIcons"), self.tSettings, "bShowCastIcons")
	
	self:UpdateStyles()
end

function ForgeUI_CastBars:ForgeAPI_AfterMovableMove()
	self:UpdateStyles()
end

-----------------------------------------------------------------------------------------------
-- ForgeUI_CastBars Instance
-----------------------------------------------------------------------------------------------
local ForgeUI_CastBarsInst = ForgeUI_CastBars:new()
ForgeUI_CastBarsInst:Init()
