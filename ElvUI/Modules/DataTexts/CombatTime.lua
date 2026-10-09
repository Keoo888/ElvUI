local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local DT = E:GetModule("DataTexts")

--Lua functions
local floor = math.floor
local join = string.join
--WoW API / Variables
local COMBAT = COMBAT

local timer = 0
local displayNumberString = ""

local lastPanel

local function OnUpdate(self, elapsed)
	timer = timer + elapsed

	--! audit perf: this ran format() every frame for the whole of every fight and
	--! threw the result away immediately. The inner string changes on every single
	--! tick (the centiseconds field guarantees it), so Lua 5.1 interned a brand new
	--! string sixty times a second — a hash of the bytes, a bucket walk, a fresh GC
	--! object, and then a sweep for the collector to pay for later, somewhere else.
	--! The template already goes through SetFormattedText, which formats in C and
	--! allocates nothing, so the time format belongs in the template rather than in
	--! a string built to be passed to it. See ValueColorUpdate below.
	--! floor() on all three on purpose: %02d truncated them before, and doing it
	--! here keeps the output byte-identical without depending on how the client's
	--! SetFormattedText treats a fractional argument to %d. floor(t / 60) is the
	--! same minute count as floor(timer / 60), and t % 60 the same second count,
	--! for any timer >= 0. Net effect is one C call fewer and one string fewer.
	local t = floor(timer)
	self.text:SetFormattedText(displayNumberString, floor(t / 60), t % 60, floor((timer - t) * 100))
end

local function OnEvent(self, event)
	if event == "PLAYER_REGEN_DISABLED" then
		timer = 0
		self:SetScript("OnUpdate", OnUpdate)
	elseif event == "PLAYER_REGEN_ENABLED" then
		self:SetScript("OnUpdate", nil)
	else
		self.text:SetFormattedText(displayNumberString, 0, 0, 0)
	end

	lastPanel = self
end

local function ValueColorUpdate(hex)
	--! audit perf: the time format lives here now instead of being built per frame
	--! in OnUpdate. Three %-places, so both call sites pass three numbers.
	displayNumberString = join("", COMBAT, ": ", hex, "%02d:%02d:%02d|r")

	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Combat Time", {"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED"}, OnEvent, nil, nil, nil, nil, L["Combat Time"])