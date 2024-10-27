--!strict

-- luexp
-- an module for hosting web api's within roblox..
-- source: github.com/czctus

local types = require(script.Parent.types)

local httpService = game:GetService('HttpService')

local lib = {}

lib.allowExternalOutput = ""

function lib.parseLuexpResponse(res: types.luexpResponse)
	for i,v in pairs(res.logging) do
		if (lib.allowExternalOutput:match(v.type) and (v.type == "warn" or v.type == "error" or v.type == "print")) then
			getfenv()[v.type](v.message)
		end
	end
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

return lib
