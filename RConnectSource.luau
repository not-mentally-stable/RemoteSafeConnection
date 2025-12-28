local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local EncodingService = game:GetService("EncodingService")

local warnv = warn
local pcallv = pcall
local typeofv = typeof
local typev = type
local taskspawn = task.spawn
local clock = time
local pack = table.pack
local unpackv = table.unpack
local huge = math.huge
local max = math.max
-- local isnan = math.isnan
-- local isinfinite = math.isinfinite

--// build-in security Config you shouldn't really tamper unless you know what your doing
local maxTableDepth = 64
local maxTableKeys = 256
local maxStringLength = 512
local minCooldown = 0.03

local warnedAllowedTypes = false --// set true if you find it annoying

local defaults = {
	BlockImpVal = false,
	AllowNegetives = true,
	AllowPositives = true,
	FilteringStrings = false,
	CheckInTables = false,
	Handling = "Default",
}

local function warnAllowedTypesOnce()
	if warnedAllowedTypes then
		return
	end
	warnv(
		"[SafeConnection] AllowedTypes uses type(), not typeof().\n" ..
		"Consider AllowedTypesOf for Roblox instances, Vector3, CFrame, enums, buffers, etc."
	)
	warnedAllowedTypes = true
end

--// pending fix... waiting for Roblox to add RFC math.isnan & math.isinf to math libary
local function isInvalidNumber(n)
	return n ~= n or n == huge or n == -huge
end

local function isAllowedType(value, allowed, useTypeof)
	local t = useTypeof and typeofv(value) or typev(value)
	for _, v in allowed do
		if v == t then
			return true
		end
	end
	return false
end

local function filterValue(value, opts, player)
	local vType = typeofv(value)

	if vType == "buffer" and opts.EniBufSize and opts.EniBufSize >= 0 then
		local size = EncodingService:GetDecompressedBufferSize(
			value,
			Enum.CompressionAlgorithm.Zstd
		)
		if size == nil or size > opts.EniBufSize then
			return false, nil
		end
	end

	if typev(value) == "number" then
		if opts.BlockImpVal and isInvalidNumber(value) then
			return false, nil
		end
		if opts.NumRange then
			if value < opts.NumRange.min or value > opts.NumRange.max then
				return false, nil
			end
		end
		if value < 0 and opts.AllowNegetives == false then
			return false, nil
		end
		if value > 0 and opts.AllowPositives == false then
			return false, nil
		end
	end

	if typev(value) == "string" then
		if #value > maxStringLength then
			return false, nil
		end
		if opts.StrRange then
			local len = #value
			if len < opts.StrRange.min or len > opts.StrRange.max then
				return false, nil
			end
		end
		if opts.FilteringStrings and player then
			local ok, filtered = pcallv(function()
				return TextService
					:FilterStringAsync(value, player.UserId)
					:GetNonChatStringForBroadcastAsync()
			end)
			if ok then
				value = filtered
			end
		end
	end

	if opts.AllowedTypes then
		warnAllowedTypesOnce()
		if not isAllowedType(value, opts.AllowedTypes, false) then
			return false, nil
		end
	end

	if opts.AllowedTypesOf then
		if not isAllowedType(value, opts.AllowedTypesOf, true) then
			return false, nil
		end
	end

	return true, value
end

local function scanTable(t, opts, player, seen, depth)
	if depth > maxTableDepth then
		return false
	end
	if seen[t] then
		return true
	end
	seen[t] = true

	local count = 0
	for k, v in t do
		count += 1
		if count > maxTableKeys then
			return false
		end

		if not filterValue(k, opts, player) then
			return false
		end

		if typev(v) == "table" and opts.CheckInTables then
			if not scanTable(v, opts, player, seen, depth + 1) then
				return false
			end
		else
			if not filterValue(v, opts, player) then
				return false
			end
		end
	end

	return true
end

local function punish(opts, player)
	if opts.CustomPunishment then
		taskspawn(opts.CustomPunishment, player, player and player.UserId)
	end
	if opts.Handling == "Kick" and player then
		player:Kick(opts.KickMsg or "Detected suspicious behavior in your client")
	end
end

local cooldowns = {}

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
end)

local SafeConnect = {}
SafeConnect.__index = SafeConnect

function SafeConnect.__call(_, filter, remote, func)
	for k, v in defaults do
		if filter[k] == nil then
			filter[k] = v
		end
	end

	if filter.AllowNegetives == false and filter.AllowPositives == false then
		warnv("[SafeConnection] AllowNegetives and AllowPositives were both false, resetting to true.")
		filter.AllowNegetives = true
		filter.AllowPositives = true
	end

	local function handler(player, ...)
		if not player or not player:IsDescendantOf(Players) then
			return nil
		end

		if filter.CoolDown then
			local now = clock()
			local cd = max(filter.CoolDown, minCooldown)

			cooldowns[player] = cooldowns[player] or {}
			local last = cooldowns[player][remote]

			if last and (now - last) < cd then
				punish(filter, player)
				return nil
			end

			cooldowns[player][remote] = now
		end

		local args = pack(...)

		for i = 1, args.n do
			local val = args[i]
			if typev(val) == "table" and filter.CheckInTables then
				if not scanTable(val, filter, player, {}, 1) then
					punish(filter, player)
					return nil
				end
			else
				local ok, newVal = filterValue(val, filter, player)
				if not ok then
					punish(filter, player)
					return nil
				end
				args[i] = newVal
			end
		end

		return func(player, unpackv(args, 1, args.n))
	end

	if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
		return remote.OnServerEvent:Connect(handler)
	else --// fake Disconnect if you call Disconnect for RemoteFunctions but you shouldn't really even use it generally
		remote.OnServerInvoke = handler
		return {
			Disconnect = function()
				remote.OnServerInvoke = nil
			end,
		}
	end
end

return setmetatable({}, SafeConnect)
