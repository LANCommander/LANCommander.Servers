--[[
	LANCommander party rotation

	Replaces the stock mapcycler. The stock game modes report the end of a match with the
	onRoundFinished event (deathmatch and briefcaserace only when a resource called "mapcycler"
	is running), so this resource keeps that name.

	  - The server starts with the "start" game mode on a random map.
	  - Race runs "race_maps" maps in a row, picked by race's own next-map vote. The vote after
	    that is replaced by a vote between game modes (race maps included).
	  - Any other mode: when its match ends (onRoundFinished), or after "time_limit" minutes for
	    modes that never end on their own, players vote for the next mode + map.
	  - Nobody votes: a random option wins. Nobody on the server: the vote waits for a player.
	  - /skipmap (admin) starts the vote now.
]]


local raceMapsLeft = 0
local limitTimer, delayTimer
local waitingForPlayer = false
local recent = {}

addEvent("onRoundFinished")
addEvent("onGamemodeStart")
addEvent("onGamemodeMapStart")
addEvent("onPollStarting")
addEvent("onPollModified")
addEvent("lcPartyChange")

local function setting(name, default)
	local value = get(name)
	if value == nil or value == false or value == "" then return default end
	return value
end

local function number(name, default)
	return tonumber(setting(name, default)) or default
end

local function say(message)
	local r, g, b = getColorFromString(string.upper(setting("color", "#F0A830")))
	outputChatBox("[Party] " .. message, root, r or 240, g or 168, b or 48)
	outputServerLog("PARTY: " .. message)
end

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function displayName(resource)
	return getResourceInfo(resource, "name") or getResourceName(resource)
end

local function isRace(gamemode)
	return gamemode and getResourceName(gamemode) == "race"
end

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Game modes from the "gamemodes" setting that exist; every mode but play when it's empty
local function getPool()
	local pool = {}
	for _, name in ipairs(split(setting("gamemodes", ""), ",")) do
		local resource = getResourceFromName(trim(name))
		if resource and exports.mapmanager:isGamemode(resource) then
			table.insert(pool, resource)
		elseif trim(name) ~= "" then
			outputDebugString("party: game mode '" .. trim(name) .. "' not found", 2)
		end
	end
	if #pool == 0 then
		for _, resource in ipairs(exports.mapmanager:getGamemodes()) do
			if getResourceName(resource) ~= "play" then table.insert(pool, resource) end
		end
	end
	return pool
end

local function isRecent(map)
	local name = getResourceName(map)
	for _, played in ipairs(recent) do
		if played == name then return true end
	end
	return false
end

-- A random map for the game mode, avoiding the running map and recently played ones.
-- nil when the mode has no maps (fallout, hay); false when its only map is the running one.
local function pickMap(gamemode)
	local maps = exports.mapmanager:getMapsCompatibleWithGamemode(gamemode)
	if #maps == 0 then return nil end
	local running = exports.mapmanager:getRunningGamemodeMap()
	local fresh, other = {}, {}
	for _, map in ipairs(maps) do
		if map ~= running then
			table.insert(other, map)
			if not isRecent(map) then table.insert(fresh, map) end
		end
	end
	local choices = #fresh > 0 and fresh or other
	if #choices == 0 then return false end
	return choices[math.random(1, #choices)]
end

local function option(gamemode, map)
	local label = map and (displayName(gamemode) .. ": " .. displayName(map)) or displayName(gamemode)
	return { label, "lcPartyChange", resourceRoot, getResourceName(gamemode), map and getResourceName(map) or false }
end

-- Poll options: one random map for each of up to vote_options modes (race always offered),
-- plus "Play again" for the running map
local function buildOptions()
	local count = math.max(2, math.min(8, number("vote_options", 6)))
	local runningMode = exports.mapmanager:getRunningGamemode()
	local pool = shuffle(getPool())

	-- Race is the crowd favourite: always offer it, and a second race map while racing
	for i, gamemode in ipairs(pool) do
		if isRace(gamemode) then
			table.remove(pool, i)
			table.insert(pool, 1, gamemode)
			if isRace(runningMode) then table.insert(pool, 2, gamemode) end
			break
		end
	end

	local options, used = {}, {}
	for _, gamemode in ipairs(pool) do
		if #options >= count then break end
		local map = pickMap(gamemode)
		if map == nil then
			if gamemode ~= runningMode then table.insert(options, option(gamemode)) end
		elseif map and not used[map] then
			used[map] = true
			table.insert(options, option(gamemode, map))
		end
	end

	local runningMap = exports.mapmanager:getRunningGamemodeMap()
	if runningMode and runningMap then
		table.insert(options, { "Play again (" .. displayName(runningMap) .. ")", "lcPartyChange", resourceRoot,
			getResourceName(runningMode), getResourceName(runningMap) })
	end
	return options
end

local function newPoll(title, options)
	local poll = { title = title, visibleTo = root, percentage = 51, timeout = 20, allowchange = true }
	for _, o in ipairs(options) do table.insert(poll, o) end
	return poll
end

local function change(modeName, mapName)
	local gamemode = getResourceFromName(modeName)
	local map = mapName and getResourceFromName(mapName)
	if not gamemode then return false end
	if map then
		return exports.mapmanager:changeGamemodeMap(map, gamemode, true)
	end
	return exports.mapmanager:changeGamemode(gamemode, nil, true)
end

addEventHandler("lcPartyChange", resourceRoot,
	function(modeName, mapName)
		if not change(modeName, mapName) then
			say("Couldn't start " .. tostring(modeName) .. (mapName and (" / " .. mapName) or "") .. "; picking another")
			setTimer(startVote, 3000, 1, true)
		end
	end
)

local function stopTimers()
	if limitTimer and isTimer(limitTimer) then killTimer(limitTimer) end
	if delayTimer and isTimer(delayTimer) then killTimer(delayTimer) end
	limitTimer, delayTimer = nil, nil
end

local function waitForPlayer()
	if not waitingForPlayer then
		waitingForPlayer = true
		outputDebugString("party: server empty; voting when a player joins")
	end
end

addEventHandler("onPlayerJoin", root,
	function()
		if waitingForPlayer then
			waitingForPlayer = false
			setTimer(startVote, 15000, 1)
		end
	end
)

-- Vote between modes now; randomOnly skips the vote (e.g. after a failed change)
function startVote(randomOnly)
	stopTimers()
	local options = buildOptions()
	if #options == 0 then
		say("No game modes to choose from; check the mapcycler 'gamemodes' setting")
		return
	end
	if #getElementsByType("player") == 0 then
		return waitForPlayer()
	end
	if randomOnly or #options == 1 then
		local o = options[math.random(1, #options)]
		return triggerEvent("lcPartyChange", resourceRoot, o[4], o[5])
	end
	exports.votemanager:stopPoll()
	if not exports.votemanager:startPoll(newPoll("Choose the next mode & map:", options)) then
		local o = options[math.random(1, #options)]
		triggerEvent("lcPartyChange", resourceRoot, o[4], o[5])
	end
end

local function remember(map)
	if not map then return end
	table.insert(recent, 1, getResourceName(map))
	while #recent > number("recent_maps", 8) do table.remove(recent) end
end

-- Every map start (and map-less mode start) begins a new "match" for the time limit
local function newMatch()
	stopTimers()
	waitingForPlayer = false
	local minutes = number("time_limit", 15)
	if minutes > 0 and not isRace(exports.mapmanager:getRunningGamemode()) then
		limitTimer = setTimer(function()
			limitTimer = nil
			say("Time's up for this one!")
			startVote()
		end, minutes * 60000, 1)
	end
end

addEventHandler("onGamemodeStart", root,
	function(gamemode)
		raceMapsLeft = number("race_maps", 3)
		if #exports.mapmanager:getMapsCompatibleWithGamemode(gamemode) == 0 then
			newMatch()
		end
	end
)

addEventHandler("onGamemodeMapStart", root,
	function(map)
		remember(map)
		if isRace(exports.mapmanager:getRunningGamemode()) then
			raceMapsLeft = raceMapsLeft - 1
			stopTimers()
		else
			newMatch()
		end
	end
)

-- A match ended (deathmatch round, CTF win, both assault halves, stealth match, briefcase race)
addEventHandler("onRoundFinished", root,
	function()
		if isRace(exports.mapmanager:getRunningGamemode()) then return end
		stopTimers()
		delayTimer = setTimer(startVote, math.max(50, number("vote_delay", 8) * 1000), 1)
	end
)

-- Race's next-map vote: after race_maps maps, swap its options for a vote between modes
addEventHandler("onPollStarting", root,
	function(poll)
		if not sourceResource or getResourceName(sourceResource) ~= "race" then return end
		if raceMapsLeft > 0 then return end
		local options = buildOptions()
		if #options < 2 then return end
		local replacement = newPoll("Choose the next mode & map:", options)
		replacement.timeout = poll.timeout or 20
		triggerEvent("onPollModified", root, replacement)
		say("Race break! Vote for the next mode")
	end
)

-- From the server console, or a player allowed to use the admin panel
addCommandHandler("skipmap",
	function(source)
		if getElementType(source) == "player" and not hasObjectPermissionTo(source, "general.adminpanel", false) then
			return outputChatBox("skipmap: access denied", source, 255, 80, 80)
		end
		startVote()
	end
)

addEventHandler("onResourceStart", resourceRoot,
	function()
		math.randomseed(getTickCount())
		raceMapsLeft = number("race_maps", 3)
		if exports.mapmanager:getRunningGamemode() then
			return newMatch()
		end
		-- Let the rest of the startup resources load first
		setTimer(function()
			if exports.mapmanager:getRunningGamemode() then return end
			local start = getResourceFromName(setting("start", ""))
			if not (start and exports.mapmanager:isGamemode(start)) then
				local pool = getPool()
				start = pool[math.random(1, #pool)]
			end
			if start then
				local map = pickMap(start)
				say("Starting " .. displayName(start))
				triggerEvent("lcPartyChange", resourceRoot, getResourceName(start), map and getResourceName(map) or false)
			end
		end, 2000, 1)
	end
)

addEventHandler("onResourceStop", resourceRoot, stopTimers)
