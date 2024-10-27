--!strict

-- luexp
-- an module for hosting web api's within roblox..
-- THIS TOOL IS BETA. IT IS NOT LICENSED FOR DISTRIBUTION OF ANY KIND, MODIFICAITON, OR PRODUCTION USE

--[[
Copyright © 2024 czctus

Permission is hereby granted, free of charge, to any person obtaining a copy of this beta software and associated documentation files (the “Software”), to use the Software for the purpose of testing and evaluating the Software, subject to the following conditions:

    No Production Use: The Software shall not be used in any production environment.
    No Modification: The Software may not be altered, modified, or adapted in any way.
    No Redistribution: The Software may not be sold, shared, sublicensed, or redistributed in any form, whether modified or unmodified.
    License Inclusion: This license must be included in all copies or substantial portions of the Software provided to testers.

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

-- source: github.com/czctus

local types = require(script.types)
local socket = require(script.socket)
local lib = require(script.lib)

local httpService = game:GetService('HttpService')
local runService = game:GetService('RunService')

local config = {
	["host"] = "https://luexp.perox.dev",
	["endpoint"] = "/luexp/%s/",
	["hostVersion"] = "v2",
	["clientVersion"] = "beta-2.0.0",
	["allowExternalOutput"] = "print,warn,error"
}

local headers = {
	["X-Luexp-Version"] = config.clientVersion
}

local luexp = {}

local function getApp(...): types.luexpApp
	local app = {}
	local appId
	local routes = {} :: {types.route}
	local ws
	local methods = {"GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "TRACE", "PATCH"}

	local function parseIncoming(data)
		local finished = false
		local index = 1
		local req = data.req :: types.req
		local res = data.res :: types.res
		local id = data.requestId

		local response = {
			inputType = "RESPOND",
			responseData = {
				status = 200,
				headers = {}
			},
			responseId = id
		}

		local function canSendHeaders()
			if (finished) then
				error("Cannot set headers after they are sent to the client", 2)
			end
		end

		function res.json(body)
			canSendHeaders()

			res.set("content-type", "application/json")
			res.send(body)

			finished = true

			return res
		end
		
		function res.redirect(url)
			canSendHeaders()
			
			response.inputType = "REDIRECT"
			response.responseData.body = url
			
			finished = true
			
			return res
		end

		function res.send(body)
			canSendHeaders()

			response.responseData.body = body

			if (typeof(body) == "buffer") then
				response.responseData.body = buffer.tostring(body)
			end

			finished = true

			return res
		end

		function res.status(code)
			canSendHeaders()

			response.responseData.status = code

			return res
		end

		function res.set(field, value)
			response.responseData.headers[field] = value

			return res
		end
		
		res.req = req
		req.res = res

		local reqm = setmetatable({}, {
			__index = req,
			__newindex = function(_:any, key:any, value:any)
				req[key] = value
			end,
		}) :: types.reqm

		local resm = setmetatable({}, {
			__index = res,
			__newindex = function(_, key, value)
				res[key] = value
			end,
		}) :: types.resm

		repeat
			local route = routes[index]
			local routeFinished = false

			index = index + 1

			if (not route) then
				res.status(404)
				res.send(`luexp: Cannot {req.method} {req.originalUrl}`)
				break
			end

			--route.ext.routes and lib.startsWithMulti(`/{req.originalUrl}`, routes)

			if (((req.originalUrl == `/{appId}{route.ext.routes}`) or (not route.ext.routes)) and (req.method == route.ext.method or route.ext.method == nil)) then
				local function next()
					routeFinished = true
				end

				local s, r = pcall(function()
					route.callback(reqm, resm, next)
				end)
				
				if (not s) then
					warn(`errored while calling callback\n{r}`)
					
					res.status(500)
					res.send(debug.traceback(r))
				end
			else
				routeFinished = true
			end

			if (not finished and not routeFinished) then
				return
			end
		until finished

		ws.send(response)
	end

	function app.listen(id:string?, callback: (url: string) -> any?)
		lib.allowExternalOutput = config.allowExternalOutput
		id = id or lib.randomString(5)
		appId = id
		local url = `{config.host}{string.format(config.endpoint, config.hostVersion)}server`
		local res = lib.fetch("POST", `{url}/{id}`, nil, headers)
		
		if (not res.Success) then
			error(`failed to start server. {res.Error or `{res.StatusCode} {res.StatusMessage}`}`, 2)
		end
		
		local client = socket:newClient(config.host, `{res.Body.message.websocket}?authorization={res.Body.message.auth}`)

		client:on("data", function(data)
			data = httpService:JSONDecode(data)

			if (not data.requestId) then
				return
			end

			parseIncoming(data)

			return
		end)

		client:connect()
		ws = client

		if (callback) then
			callback(res.Body.message.url)
		end
		
		game:BindToClose(function()
			local newHeaders = headers
			newHeaders["Authorization"] = res.Body.message.auth
			
			ws:close()
			warn("closed websocket")
			lib.fetch("DELETE", `{url}/{id}`, nil, newHeaders)
			warn("cleaned..")
			return
		end)
	end
	
	function app.use(callback: types.routeCallback)
		table.insert(routes, {
			callback = callback,
			ext = {}
		})
	end

	for _, method in pairs(methods) do
		app[string.lower(method)] = function(route:string, callback: (req: types.reqm, res: any, next: () -> nil) -> nil)
			table.insert(routes, {
				callback = callback,
				ext = {
					routes = route,
					method = method
				}
			})

			return routes
		end
	end

	return app
end

return setmetatable({}, {
	__call = function(...): types.luexpApp
		return getApp(...)
	end,
	__index = luexp :: types.luexpTbl
}) :: types.luexpMetaTbl
