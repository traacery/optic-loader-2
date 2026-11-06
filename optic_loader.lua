getgenv().OPTIC_KEY = getgenv().OPTIC_KEY or ""

local KEY_URLS = {
	"https://raw.githubusercontent.com/YOUR_USER/optic-keys-1/main/keys.txt",
	"https://raw.githubusercontent.com/YOUR_USER/optic-keys-2/main/keys.txt",
	"https://raw.githubusercontent.com/YOUR_USER/optic-keys-3/main/keys.txt",
}

local SCRIPT_URLS = {
	"https://raw.githubusercontent.com/YOUR_USER/optic-payload-1/main/optic.lua",
	"https://raw.githubusercontent.com/YOUR_USER/optic-payload-2/main/optic.lua",
}

local function httpGet(url)
	local fn = syn and syn.request or http_request or request or (http and http.request)
	if fn then
		local ok, res = pcall(fn, { Url = url, Method = "GET" })
		if ok and res then
			local body = res.Body or res.body or res.Data
			if type(body) == "string" and #body > 0 then return body end
		end
	end
	if game and game.HttpGet then
		local ok, body = pcall(function() return game:HttpGet(url) end)
		if ok and type(body) == "string" and #body > 0 then return body end
	end
	return nil
end

local function normalizeKey(k)
	return tostring(k or ""):gsub("%s+", ""):upper()
end

local function getHwid()
	local ids = {}
	pcall(function()
		local s = game:GetService("RbxAnalyticsService")
		if s and s.GetClientId then
			table.insert(ids, tostring(s:GetClientId()))
		end
	end)
	pcall(function()
		if gethwid then table.insert(ids, tostring(gethwid())) end
	end)
	pcall(function()
		if get_hwid then table.insert(ids, tostring(get_hwid())) end
	end)
	pcall(function()
		local lp = game:GetService("Players").LocalPlayer
		if lp then table.insert(ids, "UID:" .. tostring(lp.UserId)) end
	end)
	local best = ids[1] or "UNKNOWN"
	return tostring(best):gsub("%s+", "")
end

local function parseKeyLine(line)
	line = tostring(line or "")
	line = line:match("^([^#]+)") or ""
	line = line:gsub("^%s+", ""):gsub("%s+$", "")
	if line == "" then return nil, nil end
	local key, hwid = line:match("^([^|]+)|(.+)$")
	if key then
		return normalizeKey(key), tostring(hwid):gsub("%s+", "")
	end
	return normalizeKey(line), nil
end

local function keyValid(key, hwid)
	key = normalizeKey(key)
	if key == "" then return false, "empty key" end
	hwid = tostring(hwid or "")
	for _, url in ipairs(KEY_URLS) do
		local body = httpGet(url)
		if body then
			for line in string.gmatch(body .. "\n", "(.-)\n") do
				local k, locked = parseKeyLine(line)
				if k and k == key then
					if locked == nil or locked == "" then
						return false, "key has no HWID lock (owner must bind)"
					end
					if locked == hwid then
						return true, "ok"
					end
					return false, "HWID mismatch"
				end
			end
		end
	end
	return false, "key not found"
end

local function loadPayload()
	for _, url in ipairs(SCRIPT_URLS) do
		local body = httpGet(url)
		if body and #body > 100 then
			local fn = loadstring(body)
			if fn then
				local ok = pcall(fn)
				if ok then return true end
			end
		end
	end
	return false
end

if getgenv().OPTIC_ADMIN == true then
	if loadPayload() then return end
	warn("[optic] admin load failed")
	return
end

local key = normalizeKey(getgenv().OPTIC_KEY)
local hwid = getHwid()
getgenv().OPTIC_HWID = hwid

if key == "" then
	warn("[optic] no key — set getgenv().OPTIC_KEY")
	warn("[optic] your HWID: " .. hwid)
	return
end

local ok, reason = keyValid(key, hwid)
if not ok then
	warn("[optic] auth failed: " .. tostring(reason))
	warn("[optic] key: " .. key)
	warn("[optic] hwid: " .. hwid)
	return
end

if not loadPayload() then
	warn("[optic] failed to load payload")
end
