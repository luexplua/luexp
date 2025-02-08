--!strict

-- luexp
-- an module for hosting web api's within roblox..
-- source: github.com/czctus

local types = require(script.Parent.types)

local httpService = game:GetService('HttpService')

local lib = {}

lib.allowExternalOutput = ""

local function decodeChar(hex: string)
	return string.char(tonumber(hex,16))
end

local function decodeString(str)
	local output, t = string.gsub(str or "","%%(%x%x)",decodeChar)
	return output
end

function lib.getFirstOfType(type: string, ...)
	for i,v in pairs(table.pack(...)) do
		if (typeof(v) == type) then
			return v
		end
	end
	
	return nil
end

function lib.parseLuexpResponse(res: types.luexpResponse)
	local methods = {print=print, warn=warn, error=error}
	for i,v in pairs(res.logging) do
		if (lib.allowExternalOutput:match(v.type) and (v.type == "warn" or v.type == "error" or v.type == "print")) then
			local params = {v.message} :: {string | number}
			
			if (v.type == "error") then
				table.insert(params, 4)
			end
			
			methods[v.type](table.unpack(params))
		end
	end
end

function lib.matchRoutes(route: types.route, appId: string, req: types.req, appConfig: types.appConfig)
	appId = appId:gsub("([^%w])", "%%%1")
	
	local routes = route.ext.routes
	local fullRoute = `/{appId}{routes}`

	local patternRoute = "^" .. fullRoute:gsub("/:([^/]+)", "/[^/]+")
	local originalUrl = req.originalUrl
	
	if (not appConfig["strict routing"]) then
		if (patternRoute:sub(#patternRoute, #patternRoute) == "/") then
			patternRoute = patternRoute:sub(1, #patternRoute - 1)
		end
		
		patternRoute ..= "(/?)"
	end
	
	if (not appConfig["case sensitive routing"]) then
		patternRoute = patternRoute:lower()
		originalUrl = originalUrl:lower()
	end
	
	patternRoute ..= "$"

	local routeIf = (typeof(routes) ~= "table" and
		originalUrl:split("?")[1]:match(patternRoute)) 
		or routes == ".*"

	local methodIf = (req.method:match(route.ext.method)) 
		or route.ext.method == ".*"

	if typeof(routes) == "table" then
		for _, v in pairs(routes) do
			if not routeIf then
				local fullRoutePattern = `^/{appId}{v}$`
				if originalUrl:match(fullRoutePattern) then
					routeIf = true
				end
			end
		end
	end

	return (routeIf and methodIf)
end

function lib.parseParams(template: string, path: string): ({[string]: string} | nil, string | nil)
	local pattern = "^" .. template:gsub("([%.%+%-%^%$%(%)%%])", "%%%1"):gsub("/:([%w_]+)", "/([^/]+)") .. "$"
	local matches = { path:match(pattern) }
	if #matches == 0 then return nil, "path does not match the template" end

	local result, i = {}, 1
	for param in template:gmatch("/:([%w_]+)") do
		result[param] = matches[i]
		i = i + 1
	end
	return result, nil
end

function lib.parseQuery(url: string)
	local query = url:split("?")[2]
	local params = {}
	
	if (query) then
		local split = query:split("&")
		for _, queryParam in pairs(split) do
			local parts = queryParam:split("=")
			local name, value = parts[1], decodeString(parts[2]) or ""
			params[name] = value
		end
	end
	
	return params
end

function lib.includes<query>(q:query, t: {any}): boolean
	for i,v in pairs(t) do
		if (v == q) then
			return true
		end
	end
	return false
end

function lib.startsWith(s:string, q:string): boolean
	if (s:sub(1, #q) == q) then
		return true
	else
		return false
	end
end

function lib.deassert<T>(value: T, errorMessage: string?): T
	errorMessage = errorMessage or "deassertion failed!"
	if (not (value)) then
		return value :: any
	else
		error(errorMessage, 2)
	end
end

function lib.randomString(length:number, charset:string?)
	local str = ""
	local set = charset or "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
	for i=1, length do
		local selection = math.random(1, #set)
		local char = set:sub(selection, selection)
		str = str .. char
	end
	return str
end

function lib.startsWithMulti(s:string, q:{string}): boolean
	for _,v in q do
		if (lib.startsWith(s, v)) then
			return true
		end
	end
	return false
end

function lib.fetch(method: string, url:string, body: string?, headers: {[string]: string}?): types.httpResponse
	local options = {
		["Method"] = string.upper(method),
		["Body"] = body,
		["Headers"] = headers or {},
		["Url"] = url
	}

	if (not (lib.startsWithMulti(options.Url, {"http:", "https:"}))) then
		options.Url = `http://{options.Url}`
	end

	if (not (typeof(options.Headers) == "table")) then
		options.Headers = {}
		warn("headers was set to {}; headers must be a table.")
	end

	if (options.Body and not (typeof(options.Body) == "string")) then
		options.Body = nil
		warn("body was removed; body must be a string.")
	end

	if ((options.Method == "GET" or options.Method == "HEAD") and (body and typeof(body) == "string" and #body >= 1)) then
		options.Body = nil
		warn("body was removed; body should be empty for 'get' or 'head' method.")
	end

	local s, res: types.httpResponse | string = pcall(function()
		local res = httpService:RequestAsync(options) :: types.httpResponse

		if (res.Headers and res.Headers["content-type"] and res.Headers["content-type"]:match("application/json")) then
			res.Body = httpService:JSONDecode(res.Body)
		end

		return res
	end)

	if (not s) then
		warn("failed due to", res, "!")
		return {
			["Success"] = false,
			["Error"] = res :: string
		}
	else
		local res = res :: types.httpResponse

		if (res.Body and res.Body.logging) then
			lib.parseLuexpResponse(res.Body)
		end

		return res :: types.httpResponse
	end
end

function lib.combineDictionaries(dict1, dict2)
	local combined = {}

	for key, value in pairs(dict1) do
		combined[key] = value
	end

	for key, value in pairs(dict2) do
		if (combined[key]) then
			continue
		end
		
		combined[key] = value
	end

	return combined
end

return lib
