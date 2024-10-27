--!strict

-- luexp
-- an module for hosting web api's within roblox..
-- source: github.com/czctus

local types = require(script.Parent.types)
local lib = require(script.Parent.lib)

local httpService = game:GetService('HttpService')

local socket = {}

local function initSocket(socketProxy:string, host:string)
	local res = lib.fetch("POST", `{socketProxy}/new?host={host}`)
	if (not res.Error) then
		local socketId = res.Body.message.socketId
		return socketId, `{socketProxy}/sockets/{socketId}`
	else
		error(`failed to create socket. {res.Error}`, 2)
	end
end

--ev closed fires on close
--ev connected fires on ws connection
--ev data fires on data received
--ev error fires on error

function socket:newClient(proxyHost: string, host: string)
	local socketProxy = `{proxyHost}/socketProxy`
	local connection = {}
	local socketUrl
	local dataPoll = {}
	local events = {} :: {{
		["event"]: "closed" | "connected" | "data" | "error",
		["callback"]: (...any) -> nil?
	}}

	local function fireEvent(eventName: string, ...)
		for i,v in pairs(events) do
			if (v.event == eventName) then
				v.callback(...)
			end
		end
	end
	
	local function throwOrSend(eventName: string, data:any, message:string?)
		local found = false
		for i,v in pairs(events) do
			if (v.event == eventName) then
				coroutine.wrap(v.callback)(data)
				found = true
			end
		end
		if (not found) then
			error(message)
		end
	end

	function connection:on(event: "closed" | "connected" | "data" | "error", callback: (...any) -> nil?)
		table.insert(events, {
			event = event,
			callback = callback
		})
	end

	function connection:close()
		if (connection.dead) then
			error('cannot close a dead socket!')
		end

		local res = lib.fetch("DELETE", connection.url)
		connection.dead = true
		connection.id = ""
		connection.url = ""

		fireEvent('closed')
	end

	function connection:connect()
		if (not connection.dead) then
			warn("this socket is already running..")
			return
		end

		local socketId, socketDomain = initSocket(socketProxy, host)
		
		socketUrl = socketDomain

		connection.id = socketId
		connection.url = socketUrl
		connection.dead = false

		coroutine.wrap(function()
			repeat
				local res = lib.fetch("PATCH", socketUrl, httpService:JSONEncode(dataPoll), {["content-type"] = "application/json"})
				
				dataPoll = {}

				if (not (res.Error) and res.Success) then
					local data = res.Body.message
					for i,v in pairs(data) do
						fireEvent("data", v)
					end
				else
					if (res.StatusCode == 404) then
						warn("got 404")
						connection:close()
						return
					end
					throwOrSend("error", res, `unhandled exception. {res.Error or `{res.StatusCode} {res.StatusMessage}`}`)
				end
				
				task.wait(0.1)
			until connection.dead
		end)()

		fireEvent('connected', socketId)
	end

	function connection.send(data:string | {})
		table.insert(dataPoll, data)
	end

	connection.dead = true
	connection.url = ""
	connection.id = ""

	return setmetatable({}, {
		__index = connection
	})
end

return socket
