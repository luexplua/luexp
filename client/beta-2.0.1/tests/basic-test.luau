local http = game:GetService('HttpService')
local luexp = require(game.ServerScriptService.luexp)
local luexpLib = require(game.ServerScriptService.luexp.lib)
local app = luexp()

app.use(luexp.json())
app.use(function(req, res, next)
	local ip = req.headers["x-forwarded-for"] or req.ip
	req.ip = ip
	next()
end)

app.get("/", function(req, res)
	res.status(200)
	res.send("hello!")
end)

app.post("/", function(req, res)
	print("IP:", req.ip, "Body:", req.body)
	res.status(200).send()
end)

app.get("/redirect", function(req, res)
	res.redirect("https://perox.dev")
end)

app.get("/user/:id", function(req, res)
	local userId = req.params.id
	res.status(200).json({ userId = userId })
end)

app.get("/search", function(req, res)
	local q = req.query.q or "none"
	res.status(200).send("Search query: " .. q)
end)

app.use(function(req, res, next)
	print("Request:", req.method, req.originalUrl)
	next()
end)

app.disable("x-powered-by")

app.listen(`test-{luexpLib.randomString(5)}`, function(url)
	print(`Server listening on {url}!`)
	
	task.wait(0.5)
	warn("Sending test POST...")
	local postRes = luexpLib.fetch("POST", url, http:JSONEncode({ "test", "test2" }), {
		["content-type"] = "application/json"
	})

	local getRes = luexpLib.fetch("GET", url)
	print("GET response Body:", getRes.Body)
end)
