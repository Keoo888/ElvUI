--[[------------------------------------------------------------------------------------------------------
oUF_AuraWatch by Astromech
Please leave comments, suggestions, and bug reports on this addon's WoWInterface page

To setup, create a table named AuraWatch in your unit frame. There are several options
you can specify, as explained below.

	icons
		Mandatory!
		A table of frames to be used as icons. oUF_Aurawatch does not position
		these frames, so you must do so yourself. Each icon needs a spellID entry,
		which is the spell ID of the aura to watch. Table should be set up
		such that values are icon frames, but the keys can be anything.

		Note each icon can have several options set as well. See below.
	strictMatching
		Default: false
		If true, AuraWatch will only show an icon if the specific aura
		with the specified spell id is on the unit. If false, AuraWatch
		will show the icon if any aura with the same name and icon texture
		is on the unit. Strict matching can be undesireable because most
		ranks of an aura have different spell ids.
	missingAlpha
		Default 0.75
		The alpha value for icons of auras which have faded from the unit.
	presentAlpha
		Default 1
		The alpha value for icons or auras present on the unit.
	onlyShowMissing
		Default false
		If this is true, oUF_AW will hide icons if they are present on the unit.
	onlyShowPresent
		Default false
		If this is true, oUF_AW will hide icons if they have expired from the unit.
	hideCooldown
		Default false
		If this is true, oUF_AW will not create a cooldown frame
	hideCount
		Default false
		If this is true, oUF_AW will not create a count fontstring
	fromUnits
		Default {["player"] = true, ["pet"] = true, ["vehicle"] = true}
		A table of units from which auras can originate. Have the units be the keys
		and "true" be the values.
	anyUnit
		Default false
		Set to true for oUF_AW to to show an aura no matter what unit it
		originates from. This will override any fromUnits setting.
	decimalThreshold
		Default 5
		The threshold before timers go into decimal form. Set to -1 to disable decimals.
	PostCreateIcon
		Default nil
		A function to call when an icon is created to modify it, such as adding
		a border or repositioning the count fontstring. Leave as nil to ignore.
		The arguements are: AuraWatch table, icon, auraSpellID, auraName, unitFrame

Below are options set on a per icon basis. Set these as fields in the icon frames.

The following settings can be overridden from the AuraWatch table on a per-aura basis:
	onlyShowMissing
	onlyShowPresent
	hideCooldown
	hideCount
	fromUnits
	anyUnit
	decimalThreshold

The following settings are unique to icons:

	spellID
		Mandatory!
		The spell id of the aura, as explained above.
	icon
		Default aura texture
		A texture value for this icon.
	overlay
		Default Blizzard aura overlay
		An overlay for the icon. This is not created if a custom icon texture is created.
	count
		Default A fontstring
		An fontstring to show the stack count of an aura.

Here is an example of how to set oUF_AW up:

	local createAuraWatch = function(self, unit)
		local auras = {}

		-- A table of spellIDs to create icons for
		-- To find spellIDs, look up a spell on www.wowhead.com and look at the URL
		-- http://www.wowhead.com/?spell=SPELL_ID
		local spellIDs = { ... }

		auras.presentAlpha = 1
		auras.missingAlpha = .7
		auras.PostCreateIcon = myCustomIconSkinnerFunction
		-- Set any other AuraWatch settings
		auras.icons = {}
		for i, sid in pairs(spellIDs) do
			local icon = CreateFrame("Frame", nil, auras)
			icon.spellID = sid
			-- set the dimensions and positions
			icon:SetWidth(24)
			icon:SetHeight(24)
			icon:SetPoint("BOTTOM", self, "BOTTOM", 0, 28 * i)
			auras.icons[sid] = icon
			-- Set any other AuraWatch icon settings
		end
		self.AuraWatch = auras
	end
-----------------------------------------------------------------------------------------------------------]]

local _, ns = ...
local oUF = oUF or ns.oUF
assert(oUF, "oUF_AuraWatch was unable to locate oUF install")

local next = next
local pairs = pairs
--! audit perf: formatTime reached all three of these as globals, ten times a second per icon
--! with a duration text.
local format = string.format
local ceil, floor = math.ceil, math.floor

local CreateFrame = CreateFrame
local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local UnitAura = UnitAura
local UnitGUID = UnitGUID

local GUIDs = {}

local PLAYER_UNITS = {
	player = true,
	vehicle = true,
	pet = true,
}

local setupGUID
do
	local cache = setmetatable({}, {__type = "k"})

	local frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", function(self, event)
		for k, t in pairs(GUIDs) do
			GUIDs[k] = nil
			for a in pairs(t) do
				t[a] = nil
			end
			cache[t] = true
		end
	end)
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")

	function setupGUID(guid)
		local t = next(cache)
		if t then
			cache[t] = nil
		else
			t = {}
		end
		GUIDs[guid] = t
		return t
	end
end

local DAY, HOUR, MINUTE = 86400, 3600, 60
local function formatTime(s, threshold)
	if s >= DAY then
		return format("%dd", ceil(s / HOUR))
	elseif s >= HOUR then
		return format("%dh", ceil(s / HOUR))
	elseif s >= MINUTE then
		return format("%dm", ceil(s / MINUTE))
	elseif s >= threshold then
		return floor(s)
	end

	return format("%.1f", s)
end

local function updateText(self, elapsed)
	if self.timeLeft then
		self.elapsed = self.elapsed + elapsed

		if self.elapsed >= 0.1 then
			if not self.first then
				self.timeLeft = self.timeLeft - self.elapsed
			else
				self.timeLeft = self.timeLeft - GetTime()
				self.first = false
			end

			if self.timeLeft > 0 then
				if self.timeLeft <= self.textThreshold or self.textThreshold == -1 then
					self.text:SetText(formatTime(self.timeLeft, self.decimalThreshold or 5))
				else
					self.text:SetText("")
				end
			else
				self.text:SetText("")
				self:SetScript("OnUpdate", nil)

				--! audit perf: resetIcon skips reinstalling the handler while it is still on, so
				--! clear the flag here or the countdown never comes back.
				self.textScriptOn = nil
			end

			self.elapsed = 0
		end
	end
end

local function resetIcon(icon, frame, count, duration, remaining)
	if icon.onlyShowMissing then
		icon:Hide()
	else
		--! audit perf: remaining is an absolute expiration time, so start and duration are
		--! bit-identical on every pass until the buff is refreshed. Same for the stack text and
		--! the alpha, and this runs per matched aura per UNIT_AURA.
		if icon.cd then
			if duration and duration > 0 and icon.style ~= "NONE" then
				local start = remaining - duration
				if icon.cachedStart ~= start or icon.cachedDuration ~= duration then
					icon.cachedStart, icon.cachedDuration = start, duration

					icon.cd:SetCooldown(start, duration)
					icon.cd:Show()
				end
			elseif icon.cachedStart ~= false then
				icon.cachedStart, icon.cachedDuration = false, false

				icon.cd:Hide()
			end
		end

		if icon.displayText then
			icon.timeLeft = remaining
			icon.first = true
			icon.elapsed = 0

			-- updateText uninstalls itself when the timer runs out, so track that instead
			if not icon.textScriptOn then
				icon.textScriptOn = true

				icon:SetScript("OnUpdate", updateText)
			end
		end

		if icon.count then
			local text = count > 1 and count
			if icon.cachedCount ~= text then
				icon.cachedCount = text

				icon.count:SetText(text)
			end
		end

		if icon.overlay then
			icon.overlay:Hide()
		end

		if icon.cachedAlpha ~= icon.presentAlpha then
			icon.cachedAlpha = icon.presentAlpha

			icon:SetAlpha(icon.presentAlpha)
		end

		icon:Show()
	end
end

local function expireIcon(icon, frame)
	if icon.onlyShowPresent then
		icon:Hide()
	else
		--! audit perf: clearing goes through the same records resetIcon keeps, or it would skip
		--! restoring what is wiped here.
		if icon.cd and icon.cachedStart ~= false then
			icon.cachedStart, icon.cachedDuration = false, false

			icon.cd:Hide()
		end

		if icon.count and icon.cachedCount ~= nil then
			icon.cachedCount = nil

			icon.count:SetText()
		end

		if icon.overlay then
			icon.overlay:Show()
		end

		if icon.cachedAlpha ~= icon.missingAlpha then
			icon.cachedAlpha = icon.missingAlpha

			icon:SetAlpha(icon.missingAlpha)
		end

		icon:Show()
	end
end

local found = {}
local function Update(self, event, unit)
	if not unit or self.unit ~= unit then return end

	local element = self.AuraWatch
	local icons = element.watched

	--! audit perf: with nothing watched the pass still walked every buff and every debuff of the
	--! unit on each UNIT_AURA. Nothing below it can match, so leave before the first C call.
	--! watchDisabled is set by ElvUI when the indicator is switched off: the icons stay alive but
	--! none of them can be shown, so the walk is pure loss.
	if element.watchDisabled or not next(icons) then return end

	local guid = UnitGUID(unit)
	if not guid then return end

	local guidTable = GUIDs[guid]
	if not guidTable then
		guidTable = setupGUID(guid)
	end

	--! audit perf: both were read once per aura inside the scan.
	local strict = element.strictMatching
	local byName = element.watchedByName

	local filter, index = "HELPFUL", 1
	local _, name, texture, count, duration, remaining, caster, spellID
	local byTexture, icon

	while true do
		name, _, texture, count, _, duration, remaining, caster, _, _, spellID = UnitAura(unit, index, filter)

		if not name then
			if filter == "HELPFUL" then
				filter = "HARMFUL"
				index = 1
			else
				break
			end
		else
			if strict then
				icon = icons[spellID]
			else
				--! audit perf: the key was name..texture, so every aura walked cost a freshly
				--! built and interned string. The same pair is two hash reads off watchedByName.
				byTexture = byName[name]
				icon = byTexture and byTexture[texture]
			end

			if icon and (icon.anyUnit or (caster and icon.fromUnits and icon.fromUnits[caster])) then
				resetIcon(icon, element, count, duration, remaining)
				guidTable[icon] = true
				found[icon] = true
			end

			index = index + 1
		end
	end

	--! audit perf: the pass used to open by hiding or showing every watched icon and then show
	--! again whatever the scan found, so a buff that stayed up paid two visibility calls per
	--! event. Only icons the scan did not touch need a default, and that is known here.
	for _, watchedIcon in pairs(icons) do
		if not found[watchedIcon] then
			if guidTable[watchedIcon] then
				expireIcon(watchedIcon, element)
			elseif watchedIcon.onlyShowMissing then
				watchedIcon:Show()
			else
				watchedIcon:Hide()
			end
		end
	end

	for k in pairs(found) do
		found[k] = nil
	end
end

local function setupIcons(self)
	local element = self.AuraWatch
	local icons = element.icons

	element.watched = {}
	--! audit perf: second index over the same icons, so the scan can ask (name, texture) without
	--! building a key string. Rebuilt here with watched, never written anywhere else.
	element.watchedByName = {}

	for _, icon in pairs(icons) do
		local name, _, image = GetSpellInfo(icon.spellID)

		if name then
			icon.name = name

			if not icon.cd and not (element.hideCooldown or icon.hideCooldown) then
				local cd = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
				cd:SetAllPoints(icon)
				icon.cd = cd
			end

			if not icon.icon then
				local tex = icon:CreateTexture(nil, "BACKGROUND")
				tex:SetAllPoints(icon)
				tex:SetTexture(image)
				icon.icon = tex

				if not icon.overlay then
					local overlay = icon:CreateTexture(nil, "OVERLAY")
					overlay:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
					overlay:SetAllPoints(icon)
					overlay:SetTexCoord(.296875, .5703125, 0, .515625)
					overlay:SetVertexColor(1, 0, 0)
					icon.overlay = overlay
				end
			end

			if not icon.count and not (element.hideCount or icon.hideCount) then
				local count = icon:CreateFontString(nil, "OVERLAY")
				count:SetFontObject(NumberFontNormal)
				count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 0)
				icon.count = count
			end

			if icon.onlyShowMissing == nil then
				icon.onlyShowMissing = element.onlyShowMissing
			end
			if icon.onlyShowPresent == nil then
				icon.onlyShowPresent = element.onlyShowPresent
			end
			if icon.presentAlpha == nil then
				icon.presentAlpha = element.presentAlpha
			end
			if icon.missingAlpha == nil then
				icon.missingAlpha = element.missingAlpha
			end
			if icon.fromUnits == nil then
				icon.fromUnits = element.fromUnits or PLAYER_UNITS
			end
			if icon.anyUnit == nil then
				icon.anyUnit = element.anyUnit
			end

			if element.strictMatching then
				element.watched[icon.spellID] = icon
			else
				element.watched[name..image] = icon

				local byTexture = element.watchedByName[name]
				if not byTexture then
					byTexture = {}
					element.watchedByName[name] = byTexture
				end
				byTexture[image] = icon
			end

			if element.PostCreateIcon then
				element:PostCreateIcon(icon, icon.spellID, name, self)
			end
		else
			print("oUF_AuraWatch error: no spell with "..tostring(icon.spellID).." spell ID exists")
		end
	end
end

local function Enable(self)
	local element = self.AuraWatch

	if element then
		element.Update = setupIcons
		self:RegisterEvent("UNIT_AURA", Update)
		setupIcons(self)

		return true
	end
end

local function Disable(self)
	local element = self.AuraWatch

	if element then
		self:UnregisterEvent("UNIT_AURA", Update)

		for _, icon in pairs(element.icons) do
			icon:Hide()
		end
	end
end

oUF:AddElement("AuraWatch", Update, Enable, Disable)