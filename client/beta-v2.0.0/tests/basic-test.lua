local luexp = require(game.ServerScriptService.luexp)
local luexpLib = require(game.ServerScriptService.luexp.lib)
local app = luexp()

app.use(function(req, res, next)
	local ip = req.headers["x-forwarded-for"] or req.ip
	req.ip = ip
	
	next()
end)

app.get("/", function(req, res)
	res.status(200)
	res.send("hello!")
end)

app.get("/redirect", function(req, res)
	res.redirect("https://perox.dev")
end)

app.listen(`test-{luexpLib.randomString(5)}`, function(url)
	print(`server listening on {url}!`)
end)
