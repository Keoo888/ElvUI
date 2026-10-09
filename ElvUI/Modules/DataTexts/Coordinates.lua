local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local DT = E:GetModule("DataTexts")

--Lua functions
local join = string.join
--WoW API / Variables
local GetPlayerMapPosition = GetPlayerMapPosition
local ToggleFrame = ToggleFrame

local displayString = ""
local x, y = 0, 0
local lastX, lastY

local timeSinceUpdate = 0

local function OnUpdate(self, elapsed)
	timeSinceUpdate = timeSinceUpdate + elapsed

	if timeSinceUpdate > 0.03333 then
		timeSinceUpdate = 0

		x, y = GetPlayerMapPosition("player")

		--! audit perf: two decimals of a 0..100 value do not move while the player stands still, yet
		--! the FontString was redrawn 30 times a second anyway -- in town, at the bank, everywhere.
		--! ValueColorUpdate clears the cache, so a colour change still lands on the next tick.
		if x ~= lastX or y ~= lastY then
			lastX, lastY = x, y
			self.text:SetFormattedText(displayString, x * 100, y * 100)
		end
	end
end

local function OnClick()
	ToggleFrame(WorldMapFrame)
end

local function ValueColorUpdate(hex)
	displayString = join("", hex, "%.2f|r", " , ", hex, "%.2f|r")
	lastX, lastY = nil, nil
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Coords", nil, nil, OnUpdate, OnClick, nil, nil, L["Coords"])