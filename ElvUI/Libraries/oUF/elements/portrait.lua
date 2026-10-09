--[[
# Element: Portraits

Handles the updating of the unit's portrait.

## Widget

Portrait - A `PlayerModel` or a `Texture` used to represent the unit's portrait.

## Notes

A question mark model will be used if the widget is a PlayerModel and the client doesn't have the model information for
the unit.

## Examples

    -- 3D Portrait
    -- Position and size
    local Portrait = CreateFrame('PlayerModel', nil, self)
    Portrait:SetSize(32, 32)
    Portrait:SetPoint('RIGHT', self, 'LEFT')

    -- Register it with oUF
    self.Portrait = Portrait

    -- 2D Portrait
    local Portrait = self:CreateTexture(nil, 'OVERLAY')
    Portrait:SetSize(32, 32)
    Portrait:SetPoint('RIGHT', self, 'LEFT')

    -- Register it with oUF
    self.Portrait = Portrait
--]]

local _, ns = ...
local oUF = ns.oUF

local SetPortraitTexture = SetPortraitTexture
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitIsConnected = UnitIsConnected
local UnitIsUnit = UnitIsUnit
local UnitIsVisible = UnitIsVisible

local function Update(self, event, unit)
	if(not unit or not UnitIsUnit(self.unit, unit)) then return end

	local element = self.Portrait

	--[[ Callback: Portrait:PreUpdate(unit)
	Called before the element has been updated.

	* self - the Portrait element
	* unit - the unit for which the update has been triggered (string)
	--]]
	if(element.PreUpdate) then element:PreUpdate(unit) end

	local guid = UnitGUID(unit)
	local isAvailable = UnitIsConnected(unit) and UnitIsVisible(unit)
	if(event ~= 'OnUpdate' or element.guid ~= guid or element.state ~= isAvailable) then
		if(element:IsObjectType('PlayerModel')) then
			if(not isAvailable) then
				element:SetModelScale(4.25)
				element:SetCamera(0)
				element:SetPosition(0, 0, -1.5)
				element:SetModel([[Interface\Buttons\TalkToMeQuestionMark.m2]])
			elseif(element.guid ~= guid or event == 'UNIT_MODEL_CHANGED') then
				element:ClearModel()
				element:SetUnit(unit)
				element:SetModelScale(1)
				element:SetCamera(0)
				element:SetPosition(0, 0, 0)
			else
				element:SetCamera(0)
			end
		else
			SetPortraitTexture(element, unit)
		end

		element.guid = guid
		element.state = isAvailable
	end

	--[[ Callback: Portrait:PostUpdate(unit)
	Called after the element has been updated.

	* self - the Portrait element
	* unit - the unit for which the update has been triggered (string)
	--]]
	if(element.PostUpdate) then
		return element:PostUpdate(unit)
	end
end

local function Path(self, ...)
	--[[ Override: Portrait.Override(self, event, unit)
	Used to completely override the internal update function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* unit  - the unit accompanying the event (string)
	--]]
	return (self.Portrait.Override or Update) (self, ...)
end

local function ForceUpdate(element)
	return Path(element.__owner, 'ForceUpdate', element.__owner.unit)
end

--! WotLK fix: 3.3.5a has no UNIT_CONNECTION. Offline state arrives with the roster
--! events, which carry no unit, so feed the frame its own unit -- Update bails on
--! `not unit`. No unitless flag needed: events.lua:74 treats any non-UNIT_ event so.
local function RosterPath(self, event)
	if(self.unit) then
		return Path(self, event, self.unit)
	end
end

local function Enable(self, unit)
	local element = self.Portrait
	if(element) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate

		--! audit perf: unitless, because Path compares with UnitIsUnit and not with self.unit
		--! -- the fired unit may be another id for the same person. See GAP-028.
		self:RegisterEvent('UNIT_PORTRAIT_UPDATE', Path, true)
		self:RegisterEvent('UNIT_MODEL_CHANGED', Path, true)
		self:RegisterEvent('PARTY_MEMBERS_CHANGED', RosterPath)
		self:RegisterEvent('RAID_ROSTER_UPDATE', RosterPath)

		-- The quest log uses PARTY_MEMBER_{ENABLE,DISABLE} to handle updating of
		-- party members overlapping quests. This will probably be enough to handle
		-- model updating.
		--
		-- DISABLE isn't used as it fires when we most likely don't have the
		-- information we want.
		if(unit == 'party') then
			self:RegisterEvent('PARTY_MEMBER_ENABLE', Path)
		end

		element:Show()

		return true
	end
end

local function Disable(self)
	local element = self.Portrait
	if(element) then
		element:Hide()

		self:UnregisterEvent('UNIT_PORTRAIT_UPDATE', Path)
		self:UnregisterEvent('UNIT_MODEL_CHANGED', Path)
		self:UnregisterEvent('PARTY_MEMBER_ENABLE', Path)
		self:UnregisterEvent('PARTY_MEMBERS_CHANGED', RosterPath)
		self:UnregisterEvent('RAID_ROSTER_UPDATE', RosterPath)
	end
end

oUF:AddElement('Portrait', Path, Enable, Disable)