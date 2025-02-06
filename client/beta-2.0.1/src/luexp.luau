--!strict

-- luexp
-- an module for hosting web api's within roblox..
-- THIS TOOL IS BETA. IT IS NOT MEANT FOR DISTRIBUTION OF ANY KIND OR PRODUCTION USE

-- source: github.com/czctus

local types = require(script.types)
local socket = require(script.socket)
local bodyparser = require(script.bodyparser)
local lib = require(script.lib)

local httpService = game:GetService('HttpService')
local runService = game:GetService('RunService')

local config = {
	["host"] = "https://luexp.perox.dev",
	["endpoint"] = "/luexp/%s/",
	["hostVersion"] = "v2",
	["clientVersion"] = "beta-2.0.1",
	["allowExternalOutput"] = "print,warn,error"
}

local headers = {
	["X-Luexp-Version"] = config.clientVersion
}

local luexp = {}

local function getApp(...): types.luexpApp
	local app = {}
	local appConfig = {
		["case sensitive routing"] = false,
		["strict routing"] = false,
		["x-powered-by"] = true
	}
	local appId
	local routes = {} :: {types.route}
	local ws
	local methods = {"GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "TRACE", "PATCH"}

	local function parseIncoming(data)
		-- reqm & resm allow endpoints to modify values
		-- and other endpoints inherit those changes

		local finished = false
		local index = 1
		local req, res, id = data.req :: types.req, data.res :: types.res, data.requestId
		local response = {
			inputType = "RESPOND",
			responseData = {
				status = 200,
				body = nil :: any,
				headers = {}
			},
			responseId = id
		}

		local reqm = setmetatable({}, {
			__index = req,
			__newindex = function(tbl, key, value)
				rawset(tbl, key, value)
			end
		}) :: types.reqm

		local resm = setmetatable({}, {
			__index = res,
			__newindex = function(tbl, key, value)
				rawset(tbl, key, value)
			end
		}) :: types.resm

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

			if (body) then
				response.responseData.body = body

				if (typeof(body) == "buffer") then
					response.responseData.isBuffer = true
				end
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
		
		req.query = lib.parseQuery(req.originalUrl)

		res.req = req
		req.res = res

		repeat
			-- routefinished defines if next() was called
			-- finished defines if headers were sent already (thus cannot continue).

			local route, routeFinished = routes[index], false

			index = index + 1

			if (not route) then
				res.status(404)
				res.send(`luexp: Cannot {req.method} {req.originalUrl}`)
				break
			end

			local routes = route.ext.routes
			local fullRoute = `/{appId}{routes}`

			if (lib.matchRoutes(route, appId, req, appConfig)) then
				-- add params..
				-- then pcall the callback and throw a 500 if pcall fails to stop the client from hanging.
				-- next() continues progression of the route handler.
				local function next()
					routeFinished = true
				end

				if (routes and typeof(routes) ~= "table") then
					local routes, err = lib.parseParams(fullRoute, req.originalUrl)
					if (not err and routes) then
						req.params = routes
					else
						req.params = {}
					end
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
		
		if (not appConfig["x-powered-by"]) then
			-- this will only work if the server is on v1.0.1
			-- caused by the server setting the xpb header which results in us having no power over it.
			-- there is no fix to this other than just using a newer host.
			
			res.set("x-powered-by", nil)
		else
			res.set("x-powered-by", "luexp")
		end

		ws.send(response)
	end

	function app.listen(id, callback)
		lib.allowExternalOutput = config.allowExternalOutput
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
			coroutine.wrap(callback)(res.Body.message.url)
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

	function app.disable(name)
		appConfig[name] = false
	end

	function app.enable(name)
		appConfig[name] = true
	end

	function app.use(callback)
		table.insert(routes, {
			callback = callback,
			ext = {
				method = ".*",
				routes = ".*"
			}
		})
	end

	for _, method in pairs(methods) do
		app[string.lower(method)] = function(route, callback)
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

luexp.json = bodyparser.json

return setmetatable({}, {
	__call = function(...): types.luexpApp
		return getApp(...)
	end,
	__index = luexp :: types.luexpTbl
}) :: types.luexpMetaTbl
