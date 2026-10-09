local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local NP = E:GetModule("NamePlates")
local LSM = E.Libs.LSM

--Lua functions
local ipairs = ipairs
--WoW API / Variables
local CreateFrame = CreateFrame

--[[
Target Glow Style Option Variables
	style1 - Border
	style2 - Background
	style3 - Top Arrow Only
	style4 - Side Arrows Only
	style5 - Border + Top Arrow
	style6 - Background + Top Arrow
	style7 - Border + Side Arrows
	style8 - Background + Side Arrows
]]

function NP:Update_Glow(frame, healthIsShown, nameExists)
	local showIndicator

	if frame.isTarget then
		showIndicator = 1
	elseif self.db.lowHealthThreshold > 0 then
		local health = frame.oldHealthBar:GetValue()
		local _, maxHealth = frame.oldHealthBar:GetMinMaxValues()
		local perc = health / maxHealth

		if health > 1 and perc <= self.db.lowHealthThreshold then
			if perc <= self.db.lowHealthThreshold / 2 then
				showIndicator = 2
			else
				showIndicator = 3
			end
		end
	end

	local glowStyle = self.db.units.TARGET.glowStyle
	--! audit perf: NP:SetTargetFrame calls Configure_Glow and Update_Glow back to back, and
	--! both opened by reading these same two widget states (three C calls) for themselves.
	--! The pair therefore paid six reads a plate a frame for one answer. Configure_Glow now
	--! hands its answer over. On its own — the solo call sites — the arguments are absent.
	if healthIsShown == nil then
		healthIsShown = frame.Health:IsShown()
		nameExists = frame.Name:IsShown() and frame.Name:GetText() ~= nil
	end

	if not healthIsShown and not frame.IconOnlyChanged and nameExists then
		if glowStyle == "style1" then
			glowStyle = "none"
		elseif glowStyle == "style5" then
			glowStyle = "style3"
		elseif glowStyle == "style7" then
			glowStyle = "style4"
		end
	end

	--! audit perf: NP:OnUpdate reaches this for every visible plate on every frame,
	--! and the common case — a plate that is not the target and not low on health —
	--! fell through to the else branch and hid five already-hidden objects, sixty
	--! times a second, per plate. Everything below is decided by the values already
	--! computed above plus the glow colour, so once they repeat the widget calls
	--! would repeat too. Remember the decision and leave. The health is still read
	--! every frame (it has to be — that is what showIndicator depends on); what is
	--! skipped is only the work that would change nothing.
	local color = self.db.colors.glowColor
	if frame.glowShown == showIndicator and frame.glowShownStyle == glowStyle
	and frame.glowShownHealth == healthIsShown and frame.glowShownName == nameExists
	and frame.glowShownIcon == frame.IconOnlyChanged
	and frame.glowShownR == color.r and frame.glowShownG == color.g
	and frame.glowShownB == color.b then
		return
	end

	frame.glowShown, frame.glowShownStyle = showIndicator, glowStyle
	frame.glowShownHealth, frame.glowShownName = healthIsShown, nameExists
	frame.glowShownIcon = frame.IconOnlyChanged
	frame.glowShownR, frame.glowShownG, frame.glowShownB = color.r, color.g, color.b

	if showIndicator and glowStyle ~= "none" then
		local r, g, b

		if showIndicator == 1 then
			r, g, b = color.r, color.g, color.b
		elseif showIndicator == 2 then
			r, g, b = 1, 0, 0
		else
			r, g, b = 1, 1, 0
		end

		-- Indicators
		frame.TopIndicator:SetVertexColor(r, g, b)
		frame.LeftIndicator:SetVertexColor(r, g, b)
		frame.RightIndicator:SetVertexColor(r, g, b)

		if glowStyle == "style3" or glowStyle == "style5" or glowStyle == "style6" then
			frame.LeftIndicator:Hide()
			frame.RightIndicator:Hide()

			if healthIsShown or frame.IconOnlyChanged or nameExists then
				frame.TopIndicator:Show()
			end
		elseif glowStyle == "style4" or glowStyle == "style7" or glowStyle == "style8" then
			frame.TopIndicator:Hide()

			if healthIsShown or frame.IconOnlyChanged or nameExists then
				frame.LeftIndicator:Show()
				frame.RightIndicator:Show()
			end
		end

		-- Spark / Shadow
		frame.Shadow:SetBackdropBorderColor(r, g, b)
		frame.Spark:SetVertexColor(r, g, b)

		if glowStyle == "style1" or glowStyle == "style5" or glowStyle == "style7" then
			frame.Spark:Hide()

			if healthIsShown or frame.IconOnlyChanged then
				frame.Shadow:Show()
			end
		elseif glowStyle == "style2" or glowStyle == "style6" or glowStyle == "style8" then
			frame.Shadow:Hide()

			if healthIsShown or frame.IconOnlyChanged or nameExists then
				frame.Spark:Show()
			end
		elseif glowStyle == "style3" or glowStyle == "style4" then
			frame.Shadow:Hide()
			frame.Spark:Hide()
		end
	else
		frame.TopIndicator:Hide()
		frame.LeftIndicator:Hide()
		frame.RightIndicator:Hide()
		frame.Shadow:Hide()
		frame.Spark:Hide()
	end
end

function NP:Configure_Glow(frame)
	local db = self.db.units.TARGET
	local color = self.db.colors.glowColor
	local glowStyle = db.glowStyle
	local healthIsShown = frame.Health:IsShown()
	local nameExists = frame.Name:IsShown() and frame.Name:GetText() ~= nil

	--! audit perf: this is a CONFIGURE function — texture, size, anchor — and it was
	--! being run from NP:SetTargetFrame, which NP:OnUpdate calls for every visible
	--! plate on every frame. With 25 plates at 60 fps that is around 30 000 C API
	--! calls a second re-applying the same arrow texture, the same size and the same
	--! anchor point. Nothing here depends on time: the result is a function of five
	--! DB fields, the glow colour and three plate states, all of which are read
	--! anyway. So remember what the glow was last configured for and leave when none
	--! of it moved.
	--! The DB fields are part of the signature ON PURPOSE, even though the options
	--! window reaches this through ConfigureAll -> OnShow. Reading them costs table
	--! lookups, not C calls, and it means the memo cannot go stale behind an option
	--! that takes some other route in: a changed field reconfigures on the very next
	--! frame. E.Border and E.PixelMode are in for the same reason — the style1/5/7
	--! branch below calls E:Scale with them.
	if frame.glowCfgStyle == glowStyle and frame.glowCfgArrow == db.arrow
	and frame.glowCfgSize == db.arrowSize
	and frame.glowCfgX == db.arrowXOffset and frame.glowCfgY == db.arrowYOffset
	and frame.glowCfgR == color.r and frame.glowCfgG == color.g
	and frame.glowCfgB == color.b and frame.glowCfgA == color.a
	and frame.glowCfgHealth == healthIsShown and frame.glowCfgName == nameExists
	and frame.glowCfgIcon == frame.IconOnlyChanged
	and frame.glowCfgBorder == E.Border and frame.glowCfgPixel == E.PixelMode then
		return healthIsShown, nameExists
	end

	frame.glowCfgStyle, frame.glowCfgArrow = glowStyle, db.arrow
	frame.glowCfgSize = db.arrowSize
	frame.glowCfgX, frame.glowCfgY = db.arrowXOffset, db.arrowYOffset
	frame.glowCfgR, frame.glowCfgG = color.r, color.g
	frame.glowCfgB, frame.glowCfgA = color.b, color.a
	frame.glowCfgHealth, frame.glowCfgName = healthIsShown, nameExists
	frame.glowCfgIcon = frame.IconOnlyChanged
	frame.glowCfgBorder, frame.glowCfgPixel = E.Border, E.PixelMode

	if not healthIsShown and not frame.IconOnlyChanged and nameExists then
		if glowStyle == "style1" then
			glowStyle = "none"
		elseif glowStyle == "style5" then
			glowStyle = "style3"
		elseif glowStyle == "style7" then
			glowStyle = "style4"
		end
	end

	if glowStyle ~= "none" then
		local arrowSize = db.arrowSize
		local arrowXOffset, arrowYOffset = db.arrowXOffset, db.arrowYOffset
		local r, g, b, a = color.r, color.g, color.b, color.a

		-- Indicators
		frame.LeftIndicator:SetTexture(E.Media.Arrows[db.arrow])
		frame.LeftIndicator:SetVertexColor(r, g, b)
		frame.LeftIndicator:SetSize(arrowSize, arrowSize)

		frame.RightIndicator:SetTexture(E.Media.Arrows[db.arrow])
		frame.RightIndicator:SetVertexColor(r, g, b)
		frame.RightIndicator:SetSize(arrowSize, arrowSize)

		frame.TopIndicator:SetTexture(E.Media.Arrows[db.arrow])
		frame.TopIndicator:SetVertexColor(r, g, b)
		frame.TopIndicator:SetSize(arrowSize, arrowSize)

		frame.TopIndicator:ClearAllPoints()
		frame.LeftIndicator:ClearAllPoints()
		frame.RightIndicator:ClearAllPoints()

		if glowStyle == "style3" or glowStyle == "style5" or glowStyle == "style6" then
			if frame.IconOnlyChanged then
				frame.TopIndicator:SetPoint("BOTTOM", frame.IconFrame, "TOP", arrowXOffset, arrowYOffset)
			else
				if healthIsShown then
					frame.TopIndicator:SetPoint("BOTTOM", frame.Health, "TOP", arrowXOffset, arrowYOffset)
				else
					frame.TopIndicator:SetPoint("BOTTOM", frame.Name, "TOP", arrowXOffset, arrowYOffset)
				end
			end
		elseif glowStyle == "style4" or glowStyle == "style7" or glowStyle == "style8" then
			if frame.IconOnlyChanged then
				frame.LeftIndicator:SetPoint("LEFT", frame.IconFrame, "RIGHT", arrowXOffset, arrowYOffset)
				frame.RightIndicator:SetPoint("RIGHT", frame.IconFrame, "LEFT", -arrowXOffset, arrowYOffset)
			else
				if healthIsShown then
					frame.LeftIndicator:SetPoint("LEFT", frame.Health, "RIGHT", arrowXOffset, arrowYOffset)
					frame.RightIndicator:SetPoint("RIGHT", frame.Health, "LEFT", -arrowXOffset, arrowYOffset)
				else
					frame.LeftIndicator:SetPoint("LEFT", frame.Name, "RIGHT", arrowXOffset, arrowYOffset)
					frame.RightIndicator:SetPoint("RIGHT", frame.Name, "LEFT", -arrowXOffset, arrowYOffset)
				end
			end
		end

		-- Spark / Shadow
		frame.Shadow:SetBackdropBorderColor(r, g, b)
		frame.Shadow:SetAlpha(a)

		frame.Spark:SetVertexColor(r, g, b, a)
		frame.Spark:ClearAllPoints()

		if glowStyle == "style1" or glowStyle == "style5" or glowStyle == "style7" then
			frame.Shadow:SetOutside(frame.IconOnlyChanged and frame.IconFrame or frame.Health, E:Scale(E.PixelMode and 6 or 8), E:Scale(E.PixelMode and 6 or 8))
		elseif glowStyle == "style2" or glowStyle == "style6" or glowStyle == "style8" then
			if healthIsShown then
				local size = E.Border + 14
				frame.Spark:SetPoint("TOPLEFT", frame.Health, -(size * 2), size)
				frame.Spark:SetPoint("BOTTOMRIGHT", frame.Health, (size * 2), -size)
			else
				frame.Spark:SetPoint("TOPLEFT", frame.IconOnlyChanged and frame.IconFrame or frame.Name, -20, 8)
				frame.Spark:SetPoint("BOTTOMRIGHT", frame.IconOnlyChanged and frame.IconFrame or frame.Name, 20, -8)
			end
		end
	end

	return healthIsShown, nameExists
end

local Textures = {"Spark", "TopIndicator", "LeftIndicator", "RightIndicator"}

function NP:Construct_Glow(frame)
	frame.Shadow = CreateFrame("Frame", "$parentGlow", frame)
	frame.Shadow:SetFrameLevel(frame.Health:GetFrameLevel() - 1)
	frame.Shadow:SetBackdrop({edgeFile = LSM:Fetch("border", "ElvUI GlowBorder"), edgeSize = E:Scale(6)})
	frame.Shadow:Hide()

	for _, object in ipairs(Textures) do
		frame[object] = frame:CreateTexture(nil, "BACKGROUND")
		frame[object]:Hide()
	end

	frame.Spark:SetTexture(E.Media.Textures.Spark)
	frame.TopIndicator:SetTexture(E.Media.Arrows[NP.db.units.TARGET.arrow])
	frame.TopIndicator:SetTexCoord(1, 1, 1, 0, 0, 1, 0, 0) -- Rotates texture 180 degress (Up arrow to face down)
	frame.LeftIndicator:SetTexture(E.Media.Arrows[NP.db.units.TARGET.arrow])
	frame.LeftIndicator:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1) -- Rotates texture 90 degrees clockwise (Up arrow to face right)
	frame.RightIndicator:SetTexture(E.Media.Arrows[NP.db.units.TARGET.arrow])
	frame.RightIndicator:SetTexCoord(1, 1, 0, 1, 1, 0, 0, 0) -- Flips texture horizontally (Right facing arrow to face left)
end