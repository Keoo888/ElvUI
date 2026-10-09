local parent, ns = ...
local oUF = ns.oUF
local Private = oUF.Private

local argcheck = Private.argcheck
local error = Private.error
local frame_metatable = Private.frame_metatable

-- Original event methods
local registerEvent = frame_metatable.__index.RegisterEvent
local unregisterEvent = frame_metatable.__index.UnregisterEvent

function Private.UpdateUnits(frame, unit, realUnit)
	if(unit == realUnit) then
		realUnit = nil
	end

	if(frame.unit ~= unit or frame.realUnit ~= realUnit) then
		frame.unit = unit
		frame.realUnit = realUnit
		frame.id = unit:match('^.-(%d+)')
		return true
	end
end

--! audit perf: 3.3.5a has no RegisterUnitEvent, so the client hands every unit event to
--! every registered frame and this paid a C IsVisible() on each one before the element
--! handler threw the unit away. The unitEvents field was already half-wired here --
--! documented on RegisterEvent, cleared on UnregisterEvent, never filled -- so fill it and
--! ask the two table reads first. Only events nobody registered as unitless are filtered.
local function onEvent(self, event, ...)
	local unitEvents = self.unitEvents
	if(unitEvents and unitEvents[event] and self.unit ~= (...)) then return end

	if(self:IsVisible() or event == 'UNIT_COMBO_POINTS') then
		return self[event](self, event, ...)
	end
end

local event_metatable = {
	__call = function(funcs, self, ...)
		for _, func in next, funcs do
			func(self, ...)
		end
	end,
}

--[[ Events: frame:RegisterEvent(event, func, unitless)
Used to register a frame for a game event and add an event handler. OnUpdate polled frames are prevented from
registering events.

* self     - frame that will be registered for the given event.
* event    - name of the event to register (string)
* func     - function that will be executed when the event fires. If a string is passed, then a function by that name
             must be defined on the frame. Multiple functions can be added for the same frame and event
             (string or function)
* unitless - indicates that the event does not fire for a specific unit, so the event arguments won't be
             matched to the frame unit(s). Events that do not start with UNIT_ or are not known to be unit events are
             automatically considered unitless (boolean)
--]]
function frame_metatable.__index:RegisterEvent(event, func, unitless)
	-- Block OnUpdate polled frames from registering events.
	-- UNIT_PORTRAIT_UPDATE and UNIT_MODEL_CHANGED which are used for
	-- portrait updates.
	if(self.__eventless and event ~= 'UNIT_PORTRAIT_UPDATE' and event ~= 'UNIT_MODEL_CHANGED') then return end

	argcheck(event, 2, 'string')
	argcheck(func, 3, 'function')

	--! audit perf: remember whether onEvent may discard this event by unit. false is sticky:
	--! two elements can register the same event on one frame, one of them unitless (UNIT_MANA
	--! is Power plus AdditionalPower), and a single unitless handler forbids filtering for all.
	local unitEvents = self.unitEvents
	if(unitless or not event:match('^UNIT_')) then
		if(not unitEvents) then
			unitEvents = {}
			self.unitEvents = unitEvents
		end

		unitEvents[event] = false
	elseif(not unitEvents) then
		self.unitEvents = {[event] = true}
	elseif(unitEvents[event] == nil) then
		unitEvents[event] = true
	end

	local curev = self[event]
	local kind = type(curev)
	if(curev) then
		if(kind == 'function' and curev ~= func) then
			self[event] = setmetatable({curev, func}, event_metatable)
		elseif(kind == 'table') then
			for _, infunc in next, curev do
				if(infunc == func) then return end
			end

			table.insert(curev, func)
		end
	else
		self[event] = func

		if(not self:GetScript('OnEvent')) then
			self:SetScript('OnEvent', onEvent)
		end

		registerEvent(self, event)
	end
end

--[[ Events: frame:UnregisterEvent(event, func)
Used to remove a function from the event handler list for a game event.

* self  - the frame registered for the event
* event - name of the registered event (string)
* func  - function to be removed from the list of event handlers. If this is the only handler for the given event, then
          the frame will be unregistered for the event (function)
--]]
function frame_metatable.__index:UnregisterEvent(event, func)
	argcheck(event, 2, 'string')

	local cleanUp = false
	local curev = self[event]
	if(type(curev) == 'table' and func) then
		for k, infunc in next, curev do
			if(infunc == func) then
				curev[k] = nil

				break
			end
		end

		if(not next(curev)) then
			cleanUp = true
		end
	end

	if(cleanUp or curev == func) then
		self[event] = nil
		if(self.unitEvents) then
			self.unitEvents[event] = nil
		end

		unregisterEvent(self, event)
	end
end