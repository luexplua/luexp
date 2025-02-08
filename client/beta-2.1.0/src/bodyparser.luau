--!strict

-- luexp
-- an module for hosting web api's within roblox..
-- source: github.com/czctus

local types = require(script.Parent.types)
local bodyparser = {}

local function json(options): types.routeCallback
	local function isFinished(req: types.reqm)
		local type = req.body and typeof(req.body)
		if (type == "table") then
			return true
		end
		return false
	end
	
	return function(req, res, next: () -> ())
		if (isFinished(req) or not req.body or req.headers["content-type"] ~= "application/json") then
			-- skip already parsed bodies or without bodies or non json bodies
			req.body = {}
			next()
			return
		end
		
		local s,r = pcall(function()
			return game:GetService("HttpService"):JSONDecode(req.body)
		end)
		if (s) then
			req.body = r
			next()
		else
			res.status(400)
			res.send("Invalid JSON")
		end
	end
end

bodyparser.json = json
return bodyparser
