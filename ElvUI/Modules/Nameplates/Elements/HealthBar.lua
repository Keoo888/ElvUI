local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local NP = E:GetModule("NamePlates")
local LSM = E.Libs.LSM

--Lua functions
local tinsert = table.insert
--WoW API / Variables
local CreateFrame = CreateFrame
--! audit perf: Update_HealthColor reads this per health tick of every visible plate. The
--! 18 other files that cache it at load prove it is never reassigned; CUSTOM_CLASS_COLORS
--! stays a live global read because a separate addon may create it after we load.
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

function NP:Update_HealthOnValueChanged()
	--! audit perf: field set next to the hook in OnCreated, instead of a C call plus a
	--! table read on every health tick of every visible plate.
	local frame = self.unitFrame
	if not frame.UnitType then return end -- Bugs

	NP:Update_Health(frame)
	NP:Update_HealthColor(frame)
	NP:Update_Glow(frame)
	NP:StyleFilterUpdate(frame, "UNIT_HEALTH")
end

function NP:Update_HealthColor(frame)
	if not frame.Health:IsShown() then return end

	local r, g, b
	local scale = 1

	--! audit perf: the class colour and the five-deep db walk were paid before the test that
	--! throws both away -- every NPC plate and every player plate with useClassColor off.
	--! Cheapest discriminator first, foreign table last. Same guard the sibling Name.lua has.
	local unitType = frame.UnitType
	local classColor
	if unitType == "FRIENDLY_PLAYER" or unitType == "ENEMY_PLAYER" then
		local class = frame.UnitClass
		if class and NP.db.units[unitType].health.useClassColor then
			classColor = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class] or RAID_CLASS_COLORS[class]
		end
	end

	if classColor then
		r, g, b = classColor.r, classColor.g, classColor.b
	else
		local db = self.db.colors
		local status = frame.ThreatStatus
		if status then
			if status == 3 then
				if E.Role == "Tank" then
					r, g, b = db.threat.goodColor.r, db.threat.goodColor.g, db.threat.goodColor.b
					scale = NP.db.threat.goodScale
				else
					r, g, b = db.threat.badColor.r, db.threat.badColor.g, db.threat.badColor.b
					scale = NP.db.threat.badScale
				end
			elseif status == 2 then
				if E.Role == "Tank" then
					r, g, b = db.threat.badTransition.r, db.threat.badTransition.g, db.threat.badTransition.b
				else
					r, g, b = db.threat.goodTransition.r, db.threat.goodTransition.g, db.threat.goodTransition.b
				end
				scale = 1
			elseif status == 1 then
				if E.Role == "Tank" then
					r, g, b = db.threat.goodTransition.r, db.threat.goodTransition.g, db.threat.goodTransition.b
				else
					r, g, b = db.threat.badTransition.r, db.threat.badTransition.g, db.threat.badTransition.b
				end
				scale = 1
			else
				if E.Role == "Tank" then
					r, g, b = db.threat.badColor.r, db.threat.badColor.g, db.threat.badColor.b
					scale = self.db.threat.badScale
				else
					r, g, b = db.threat.goodColor.r, db.threat.goodColor.g, db.threat.goodColor.b
					scale = self.db.threat.goodScale
				end
			end
		end

		if (not status) or (status and not NP.db.threat.useThreatColor) then
			local reactionType = frame.UnitReaction
			if reactionType == 4 then
				r, g, b = db.reactions.neutral.r, db.reactions.neutral.g, db.reactions.neutral.b
			elseif reactionType and reactionType > 4 then
				if unitType == "FRIENDLY_PLAYER" then
					r, g, b = db.reactions.friendlyPlayer.r, db.reactions.friendlyPlayer.g, db.reactions.friendlyPlayer.b
				else
					r, g, b = db.reactions.good.r, db.reactions.good.g, db.reactions.good.b
				end
			else
				r, g, b = db.reactions.bad.r, db.reactions.bad.g, db.reactions.bad.b
			end
		end
	end

	if r ~= frame.Health.r or g ~= frame.Health.g or b ~= frame.Health.b then
		if not frame.HealthColorChanged then
			frame.Health:SetStatusBarColor(r, g, b)

			if frame.HealthColorChangeCallbacks then
				--! audit perf: a dense array built only by tinsert below, so a numeric for is
				--! exact and drops the ipairs global plus its iterator call per tick per plate.
				local cbs = frame.HealthColorChangeCallbacks
				for i = 1, #cbs do
					cbs[i](self, frame, r, g, b)
				end
			end
		end
		frame.Health.r, frame.Health.g, frame.Health.b = r, g, b
	end

	if frame.ThreatScale ~= scale then
		frame.ThreatScale = scale
		if frame.isTarget and self.db.useTargetScale then
			scale = scale * self.db.targetScale
		end
		self:SetFrameScale(frame, scale * (frame.ActionScale or 1))
	end
end

function NP:Update_Health(frame)
	if not frame.Health:IsShown() then return end

	local health = frame.oldHealthBar:GetValue()
	local _, maxHealth = frame.oldHealthBar:GetMinMaxValues()
	--! audit perf: max health changes on buffs and level-ups, not on every tick, and this is
	--! the only writer of the bar's range. Skipping the equal write costs no clamping.
	if frame.Health.maxSetValue ~= maxHealth then
		frame.Health.maxSetValue = maxHealth
		frame.Health:SetMinMaxValues(0, maxHealth)
	end

	if frame.HealthValueChangeCallbacks then
		local cbs = frame.HealthValueChangeCallbacks
		for i = 1, #cbs do
			cbs[i](self, frame, health, maxHealth)
		end
	end

	frame.Health:SetValue(health)
	frame.FlashTexture:Point("TOPRIGHT", frame.Health:GetStatusBarTexture(), "TOPRIGHT") --idk why this fixes this

	--! audit perf: the same five-deep path was walked twice per health tick of every visible
	--! plate, once for the flag and once for the format string.
	local text = self.db.units[frame.UnitType].health.text
	if text.enable then
		frame.Health.Text:SetText(E:GetFormattedText(text.format, health, maxHealth))
	end
end

function NP:RegisterHealthBarCallbacks(frame, valueChangeCB, colorChangeCB)
	if valueChangeCB then
		frame.HealthValueChangeCallbacks = frame.HealthValueChangeCallbacks or {}
		tinsert(frame.HealthValueChangeCallbacks, valueChangeCB)
	end

	if colorChangeCB then
		frame.HealthColorChangeCallbacks = frame.HealthColorChangeCallbacks or {}
		tinsert(frame.HealthColorChangeCallbacks, colorChangeCB)
	end
end

function NP:Update_HealthBar(frame)
	if self.db.units[frame.UnitType].health.enable or (frame.isTarget and self.db.alwaysShowTargetHealth) then
		frame.Health:Show()
	else
		frame.Health:Hide()
	end
end

function NP:Configure_HealthBarScale(frame, scale, noPlayAnimation)
	if noPlayAnimation then
		frame.Health:SetWidth(self.db.units[frame.UnitType].health.width * scale)
		frame.Health:SetHeight(self.db.units[frame.UnitType].health.height * scale)
	else
		if frame.Health.scale:IsPlaying() then
			frame.Health.scale:Stop()
		end

		frame.Health.scale.width:SetChange(self.db.units[frame.UnitType].health.width * scale)
		frame.Health.scale.height:SetChange(self.db.units[frame.UnitType].health.height * scale)
		frame.Health.scale:Play()
	end
end

function NP:Configure_HealthBar(frame, configuring)
	local db = self.db.units[frame.UnitType].health
	local healthBar = frame.Health

	healthBar:SetPoint("TOP", frame, "TOP", 0, 0)

	if configuring then
		healthBar:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.statusbar), "BORDER")

		self:Configure_HealthBarScale(frame, frame.currentScale or 1, configuring)

		E:SetSmoothing(healthBar, self.db.smoothbars)

		if db.text.enable then
			healthBar.Text:ClearAllPoints()
			healthBar.Text:Point(E.InversePoints[db.text.position], db.text.parent == "Nameplate" and frame or frame[db.text.parent], db.text.position, db.text.xOffset, db.text.yOffset)
			healthBar.Text:FontTemplate(LSM:Fetch("font", db.text.font), db.text.fontSize, db.text.fontOutline)
			healthBar.Text:Show()
		else
			healthBar.Text:Hide()
		end
	end
end

local function HealthBar_OnSizeChanged(self, width)
	local health = self:GetValue()
	local _, maxHealth = self:GetMinMaxValues()
	self:GetStatusBarTexture():SetPoint("TOPRIGHT", -(width * ((maxHealth - health) / maxHealth)), 0)
end

function NP:Construct_HealthBar(parent)
	local frame = CreateFrame("StatusBar", "$parentHealthBar", parent)
	frame:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.statusbar), "BORDER")
	self:StyleFrame(frame)

	frame:SetScript("OnSizeChanged", HealthBar_OnSizeChanged)

	parent.FlashTexture = frame:CreateTexture(nil, "OVERLAY")
	parent.FlashTexture:SetTexture(LSM:Fetch("background", "ElvUI Blank"))
	parent.FlashTexture:Point("BOTTOMLEFT", frame:GetStatusBarTexture(), "BOTTOMLEFT")
	parent.FlashTexture:Point("TOPRIGHT", frame:GetStatusBarTexture(), "TOPRIGHT")
	parent.FlashTexture:Hide()

	frame.Text = frame:CreateFontString(nil, "OVERLAY")
	frame.Text:SetAllPoints(frame)
	frame.Text:SetWordWrap(false)

	frame.scale = CreateAnimationGroup(frame)
	frame.scale.width = frame.scale:CreateAnimation("Width")
	frame.scale.width:SetDuration(0.2)
	frame.scale.height = frame.scale:CreateAnimation("Height")
	frame.scale.height:SetDuration(0.2)

	frame:Hide()

	return frame
end