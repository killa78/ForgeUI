-----------------------------------------------------------------------------------------------
-- Client Lua Script for ForgeUI_NeedGreed
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Sound"

local ForgeUI_NeedGreed = {}

local ktEvalColors =
{
	[Item.CodeEnumItemQuality.Inferior] 		= ApolloColor.new("ItemQuality_Inferior"),
	[Item.CodeEnumItemQuality.Average] 			= ApolloColor.new("ItemQuality_Average"),
	[Item.CodeEnumItemQuality.Good] 			= ApolloColor.new("ItemQuality_Good"),
	[Item.CodeEnumItemQuality.Excellent] 		= ApolloColor.new("ItemQuality_Excellent"),
	[Item.CodeEnumItemQuality.Superb] 			= ApolloColor.new("ItemQuality_Superb"),
	[Item.CodeEnumItemQuality.Legendary] 		= ApolloColor.new("ItemQuality_Legendary"),
	[Item.CodeEnumItemQuality.Artifact]		 	= ApolloColor.new("ItemQuality_Artifact"),
}

function ForgeUI_NeedGreed:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	-- mandatory 
    self.api_version = 2
	self.version = "0.1.0"
	self.author = "WintyBadass"
	self.strAddonName = "ForgeUI_NeedGreed"
	self.strDisplayName = "Need vs Greed"
	
	self.wndContainers = {}
	
	self.tStylers = {}
	
	-- optional
	self.settings_version = 1
    self.tSettings = {}

    return o
end

function ForgeUI_NeedGreed:Init()
    Apollo.RegisterAddon(self)
end

function ForgeUI_NeedGreed:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ForgeUI_NeedGreed.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function ForgeUI_NeedGreed:OnDocumentReady()
	if self.xmlDoc == nil and not self.xmlDoc:IsLoaded() then return end
	
	if ForgeUI == nil then -- forgeui loaded
		ForgeUI = Apollo.GetAddon("ForgeUI")
	end
	
	ForgeUI.API_RegisterAddon(self)
end

function ForgeUI_NeedGreed:ForgeAPI_AfterRegistration()
	Apollo.RegisterEventHandler("LootRollUpdate",		"OnGroupLoot", self)
    Apollo.RegisterTimerHandler("WinnerCheckTimer", 	"OnOneSecTimer", self)
    Apollo.RegisterEventHandler("LootRollWon", 			"OnLootRollWon", self)
    Apollo.RegisterEventHandler("LootRollAllPassed", 	"OnLootRollAllPassed", self)

	Apollo.RegisterEventHandler("LootRollSelected", 	"OnLootRollSelected", self)
	Apollo.RegisterEventHandler("LootRollPassed", 		"OnLootRollPassed", self)
	Apollo.RegisterEventHandler("LootRoll", 			"OnLootRoll", self)

	--Apollo.RegisterEventHandler("GroupBagItemAdded", 	"OnGroupBagItemAdded", self) -- Appears deprecated

	Apollo.CreateTimer("WinnerCheckTimer", 1.0, false)
	Apollo.StopTimer("WinnerCheckTimer")
	
	self.wndContainer = Apollo.LoadForm(self.xmlDoc, "Container", nil, self)
	
	ForgeUI.API_RegisterWindow(self, self.wndContainer, "ForgeUI_NeedGreedContainer", { strDisplayName = "Need vs Greed", bSizable = false })

	self.bTimerRunning = false
	self.tKnownLoot = nil
	self.tLootRolls = nil

	if GameLib.GetLootRolls() then
		self:OnGroupLoot()
	end
end

-----------------------------------------------------------------------------------------------
-- Main Draw Method
-----------------------------------------------------------------------------------------------
function ForgeUI_NeedGreed:OnGroupLoot()
	if not self.bTimerRunning then
		Apollo.StartTimer("WinnerCheckTimer")
		self.bTimerRunning = true
	end
end

function ForgeUI_NeedGreed:UpdateKnownLoot()
	self.tLootRolls = GameLib.GetLootRolls()
	if not self.tLootRolls or #self.tLootRolls <= 0 then
		self.tKnownLoot = nil
		self.tLootRolls = nil
		return
	end

	self.tKnownLoot = {}
	for idx, tCurrentElement in ipairs(self.tLootRolls) do
		self.tKnownLoot[tCurrentElement.nLootId] = tCurrentElement
	end
end

function ForgeUI_NeedGreed:OnOneSecTimer()
	self:UpdateKnownLoot()

	if self.tLootRolls then
		--self:DrawAllLoot(self.tLootRolls, #self.tLootRolls)
		self:DrawAllLoot(self.tKnownLoot, #self.tLootRolls)
	else
		self.wndContainer:DestroyChildren()
	end

	if self.tLootRolls and #self.tLootRolls > 0 then
		Apollo.StartTimer("WinnerCheckTimer")
	else
		self.bTimerRunning = false
	end
end

function ForgeUI_NeedGreed:DrawAllLoot(tLoot, nLoot)
	if nLoot == 0 then 
		self.wndContainer:DestroyChildren()
		return
	end

	for _, wnd in pairs(self.wndContainer:GetChildren()) do
		local bShouldBeDestroyed = true
		for _, loot in pairs(tLoot) do
			if wnd:GetData() == loot.nLootId then
				bShouldBeDestroyed = false
			end
		end
		
		if bShouldBeDestroyed then
			wnd:Destroy()
		end
	end
	
	--self.wndContainer:DestroyChildren()
	for k, tCurrentElement in pairs(tLoot) do
		local bShouldBeAdded = true
		
		local wndLoot
		
		for _, wnd in pairs(self.wndContainer:GetChildren()) do
			if wnd:GetData() == tCurrentElement.nLootId then
				bShouldBeAdded = false
				wndLoot = wnd
			end
		end
	
		if bShouldBeAdded then
			wndLoot = Apollo.LoadForm(self.xmlDoc, "ForgeUI_NeedGreedForm", self.wndContainer, self)
			
			wndLoot:SetData(tCurrentElement.nLootId)
			
			local itemCurrent = tCurrentElement.itemDrop
			local itemModData = tCurrentElement.tModData
			local tGlyphData = tCurrentElement.tSigilData
			wndLoot:FindChild("LootTitle"):SetText(itemCurrent:GetName())
			wndLoot:FindChild("LootTitle"):SetTextColor(ktEvalColors[itemCurrent:GetItemQuality()])
			wndLoot:FindChild("GiantItemIcon"):SetData(itemCurrent)
			wndLoot:FindChild("GiantItemIcon"):SetSprite(itemCurrent:GetIcon())
			self:HelperBuildItemTooltip(wndLoot:FindChild("GiantItemIcon"), itemCurrent, itemModData, tGlyphData)
			
			wndLoot:FindChild("NeedBtn"):Show(GameLib.IsNeedRollAllowed(tCurrentElement.nLootId))
			
		end
		
		local nTimeLeft = math.floor(tCurrentElement.nTimeLeft / 1000)
		wndLoot:FindChild("TimeLeftText"):Show(true)
	
		local nTimeLeftSecs = nTimeLeft % 60
		local nTimeLeftMins = math.floor(nTimeLeft / 60)
	
		local strTimeLeft = tostring(nTimeLeftMins)
		if nTimeLeft < 0 then
			strTimeLeft = "0:00"
		elseif nTimeLeftSecs < 10 then
			strTimeLeft = strTimeLeft .. ":0" .. tostring(nTimeLeftSecs)
		else
			strTimeLeft = strTimeLeft .. ":" .. tostring(nTimeLeftSecs)
		end
		wndLoot:FindChild("TimeLeftText"):SetText(strTimeLeft)
	end
	
	self.wndContainer:ArrangeChildrenVert(2)
end

-----------------------------------------------------------------------------------------------
-- Chat Message Events
-----------------------------------------------------------------------------------------------

function ForgeUI_NeedGreed:OnLootRollAllPassed(itemLooted)
	local strResult = String_GetWeaselString(Apollo.GetString("NeedVsGreed_EveryonePassed"), itemLooted:GetChatLinkString())
	Event_FireGenericEvent("GenericEvent_LootChannelMessage", strResult)
end

function ForgeUI_NeedGreed:OnLootRollWon(itemLoot, strWinner, bNeed)
	local strNeedOrGreed = nil
	if bNeed then
		strNeedOrGreed = Apollo.GetString("NeedVsGreed_NeedRoll")
	else
		strNeedOrGreed = Apollo.GetString("NeedVsGreed_GreedRoll")
	end
	
	local strResult = String_GetWeaselString(Apollo.GetString("NeedVsGreed_ItemWon"), strWinner, itemLoot:GetChatLinkString(), strNeedOrGreed)
	Event_FireGenericEvent("GenericEvent_LootChannelMessage", strResult)
end

function ForgeUI_NeedGreed:OnLootRollSelected(itemLoot, strPlayer, bNeed)
	local strNeedOrGreed = nil
	if bNeed then
		strNeedOrGreed = Apollo.GetString("NeedVsGreed_NeedRoll")
	else
		strNeedOrGreed = Apollo.GetString("NeedVsGreed_GreedRoll")
	end

	local strResult = String_GetWeaselString(Apollo.GetString("NeedVsGreed_LootRollSelected"), strPlayer, strNeedOrGreed, itemLoot:GetChatLinkString())
	Event_FireGenericEvent("GenericEvent_LootChannelMessage", strResult)
end

function ForgeUI_NeedGreed:OnLootRollPassed(itemLoot, strPlayer)
	local strResult = String_GetWeaselString(Apollo.GetString("NeedVsGreed_PlayerPassed"), strPlayer, itemLoot:GetChatLinkString())
	Event_FireGenericEvent("GenericEvent_LootChannelMessage", strResult)
end

function ForgeUI_NeedGreed:OnLootRoll(itemLoot, strPlayer, nRoll, bNeed)
	local strNeedOrGreed = nil
	if bNeed then
		strNeedOrGreed = Apollo.GetString("NeedVsGreed_NeedRoll")
	else
		strNeedOrGreed = Apollo.GetString("NeedVsGreed_GreedRoll")
	end
	
	local strResult = String_GetWeaselString(Apollo.GetString("NeedVsGreed_OnLootRoll"), strPlayer, nRoll, itemLoot:GetChatLinkString(), strNeedOrGreed)
	Event_FireGenericEvent("GenericEvent_LootChannelMessage", strResult)
end

-----------------------------------------------------------------------------------------------
-- Buttons
-----------------------------------------------------------------------------------------------

function ForgeUI_NeedGreed:OnGiantItemIconMouseUp(wndHandler, wndControl, eMouseButton)
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and wndHandler:GetData() then
		Event_FireGenericEvent("GenericEvent_ContextMenuItem", wndHandler:GetData())
	end
end

function ForgeUI_NeedGreed:OnNeedBtn(wndHandler, wndControl)
	local wndLoot = wndControl:GetParent():GetParent()

	GameLib.RollOnLoot(wndLoot:GetData(), true)
	self:UpdateKnownLoot()
	wndLoot:Destroy()
	
	self.wndContainer:ArrangeChildrenVert(2)
end

function ForgeUI_NeedGreed:OnGreedBtn(wndHandler, wndControl)
	local wndLoot = wndControl:GetParent():GetParent()

	GameLib.RollOnLoot(wndLoot:GetData(), false)
	self:UpdateKnownLoot()
	wndLoot:Destroy()
	
	self.wndContainer:ArrangeChildrenVert(2)
end

function ForgeUI_NeedGreed:OnPassBtn(wndHandler, wndControl)
	local wndLoot = wndControl:GetParent():GetParent()

	GameLib.PassOnLoot(wndLoot:GetData(), true)
	self:UpdateKnownLoot()
	wndLoot:Destroy()
	
	self.wndContainer:ArrangeChildrenVert(2)
end

function ForgeUI_NeedGreed:HelperBuildItemTooltip(wndArg, itemCurr, itemModData, tGlyphData)
	wndArg:SetTooltipDoc(nil)
	wndArg:SetTooltipDocSecondary(nil)
	local itemEquipped = itemCurr:GetEquippedItemForItemType()
	Tooltip.GetItemTooltipForm(self, wndArg, itemCurr, {bPrimary = true, bSelling = false, itemCompare = itemEquipped, itemModData = itemModData, tGlyphData = tGlyphData})
end

local ForgeUI_NeedGreedInst = ForgeUI_NeedGreed:new()
ForgeUI_NeedGreedInst:Init()