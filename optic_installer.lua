local KEY_URLS = {
	"https://raw.githubusercontent.com/YOUR_USER/optic-keys-1/main/keys.txt",
	"https://raw.githubusercontent.com/YOUR_USER/optic-keys-2/main/keys.txt",
	"https://raw.githubusercontent.com/YOUR_USER/optic-keys-3/main/keys.txt",
}

local LOADER_URLS = {
	"https://raw.githubusercontent.com/YOUR_USER/optic-loader-1/main/loader.lua",
	"https://raw.githubusercontent.com/YOUR_USER/optic-loader-2/main/loader.lua",
}

local PAYLOAD_URLS = {
	"https://raw.githubusercontent.com/YOUR_USER/optic-payload-1/main/optic.lua",
	"https://raw.githubusercontent.com/YOUR_USER/optic-payload-2/main/optic.lua",
}

local WORKSPACE_LOADER = "optic_loader.lua"
local WORKSPACE_MAIN = "optic.lua"
local WORKSPACE_ADMIN = "optic_admin.lua"

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

local function fetchFirst(urls)
	for _, url in ipairs(urls) do
		local body = httpGet(url)
		if body and #body > 20 then return body, url end
	end
	return nil, nil
end

local function normalizeKey(k)
	return tostring(k or ""):gsub("%s+", ""):upper()
end

local function getHwid()
	local ids = {}
	pcall(function()
		local s = game:GetService("RbxAnalyticsService")
		if s and s.GetClientId then table.insert(ids, tostring(s:GetClientId())) end
	end)
	pcall(function() if gethwid then table.insert(ids, tostring(gethwid())) end end)
	pcall(function() if get_hwid then table.insert(ids, tostring(get_hwid())) end end)
	pcall(function()
		local lp = game:GetService("Players").LocalPlayer
		if lp then table.insert(ids, "UID:" .. tostring(lp.UserId)) end
	end)
	return tostring(ids[1] or "UNKNOWN"):gsub("%s+", "")
end

local function parseKeyLine(line)
	line = tostring(line or "")
	line = line:match("^([^#]+)") or ""
	line = line:gsub("^%s+", ""):gsub("%s+$", "")
	if line == "" then return nil, nil end
	local key, hwid = line:match("^([^|]+)|(.+)$")
	if key then return normalizeKey(key), tostring(hwid):gsub("%s+", "") end
	return normalizeKey(line), nil
end

local function keyValid(key, hwid)
	key = normalizeKey(key)
	if key == "" then return false, "empty" end
	for _, url in ipairs(KEY_URLS) do
		local body = httpGet(url)
		if body then
			for line in string.gmatch(body .. "\n", "(.-)\n") do
				local k, locked = parseKeyLine(line)
				if k and k == key then
					if not locked or locked == "" then
						return false, "key not HWID-bound yet"
					end
					if locked == hwid then return true, "ok" end
					return false, "HWID mismatch"
				end
			end
		end
	end
	return false, "key not found"
end

local function writeWS(name, data)
	if not writefile then return false end
	return pcall(writefile, name, data) == true
end

local key = normalizeKey(getgenv().OPTIC_INSTALL_KEY or "")
local hwid = getHwid()
getgenv().OPTIC_HWID = hwid

print("[optic installer] hwid: " .. hwid)

if key == "" then
	warn("[optic installer] set getgenv().OPTIC_INSTALL_KEY = 'YOURKEY' then rerun")
	warn("[optic installer] send this HWID to the owner to bind your key: " .. hwid)
	return
end

local ok, reason = keyValid(key, hwid)
if not ok then
	warn("[optic installer] auth failed: " .. tostring(reason))
	warn("[optic installer] key=" .. key .. " hwid=" .. hwid)
	return
end

local loaderBody = select(1, fetchFirst(LOADER_URLS))
local payloadBody = select(1, fetchFirst(PAYLOAD_URLS))
if not loaderBody then warn("[optic installer] loader download failed") return end
if not payloadBody then warn("[optic installer] payload download failed") return end

local keyLine = "getgenv().OPTIC_KEY = " .. string.format("%q", key) .. "\n"
local embeddedLoader = keyLine .. loaderBody
local embeddedMain = keyLine .. "-- key pre-set; prefer loader for auth\n" .. payloadBody
local adminBody = "getgenv().OPTIC_ADMIN = true\n" .. payloadBody

if writeWS(WORKSPACE_LOADER, embeddedLoader) then
	print("[optic installer] wrote " .. WORKSPACE_LOADER)
else
	warn("[optic installer] failed writing loader")
end

if writeWS(WORKSPACE_MAIN, embeddedMain) then
	print("[optic installer] wrote " .. WORKSPACE_MAIN .. " (payload only; use loader for HWID check)")
end

print("[optic installer] done. run: loadfile('optic_loader.lua')()")
print("[optic installer] admin file is NOT written for users. owner keeps optic_admin.lua offline.")
