--!strict

-- luexp
-- an module for hosting web api's within roblox..
-- source: github.com/czctus

export type httpResponse = {
	["Body"]: any?,
	["Headers"]: {
		["content-type"]:string?,
		["content-length"]:number?,
		[string]: string
	}?,
	["StatusCode"]: number?,
	["StatusMessage"]: string?,
	["Success"]: boolean?,
	["Error"]: string?
}

export type luexpResponse = {
	["error"]: nil | string,
	["message"]: any,
	["logging"]: {
		{type: string, message: string}
	}
}

export type headers = { -- ow
	["x-requested-with"]: string,
	["x-forwarded-for"]: string,
	["x-forwarded-host"]: string,
	["x-forwarded-proto"]: string,
	["x-real-ip"]: string,
	["x-api-key"]: string,
	["x-client-ip"]: string,
	["x-frame-options"]: string,
	["x-ua-compatible"]: string,
	["x-csrf-token"]: string,
	["x-xsrf-token"]: string,
	["x-auth-token"]: string,
	["x-content-type-options"]: string,
	["x-origin"]: string,
	["x-wap-profile"]: string,
	["x-dnt"]: number,
	["x-device-user-agent"]: string,
	["x-device-os"]: string,
	["x-app-version"]: string,
	["x-app-platform"]: string,
	["x-app-device-id"]: string,
	["x-app-language"]: string,
	["x-app-environment"]: string,
	["x-user-token"]: string,
	["x-app-signature"]: string,
	["x-session-id"]: string,
	["x-user-id"]: string,
	["x-debug-token"]: string,
	["x-request-id"]: string,
	["x-request-identifier"]: string,
	["x-device-id"]: string,
	["x-device-type"]: string,
	["x-language"]: string,
	["x-referrer"]: string,
	["x-region"]: string,
	["x-referer"]: string,
	["x-real-user-ip"]: string,
	["x-application-name"]: string,
	["x-cluster-client-ip"]: string,
	["accept"]: string,
	["accept-charset"]: string,
	["accept-encoding"]: string,
	["accept-language"]: string,
	["authorization"]: string,
	["cache-control"]: string,
	["connection"]: string,
	["content-length"]: number,
	["content-type"]: string,
	["cookie"]: string,
	["host"]: string,
	["if-modified-since"]: string,
	["if-none-match"]: string,
	["origin"]: string,
	["pragma"]: string,
	["proxy-authorization"]: string,
	["referer"]: string,
	["sec-ch-ua"]: string,
	["sec-ch-ua-mobile"]: string,
	["sec-fetch-dest"]: string,
	["sec-fetch-mode"]: string,
	["sec-fetch-site"]: string,
	["sec-fetch-user"]: string,
	["te"]: string,
	["upgrade-insecure-requests"]: number,
	["user-agent"]: string,
	["via"]: string,
	["warning"]: string,
	["x-client-data"]: string,
	[string]: string,
}

export type req = {
	headers: headers,
	baseUrl: string,
	body: string? | {[number | string]: string | boolean | number}?,
	fresh: boolean,
	host: string,
	hostname: string,
	ip: string,
	ips: {string},
	method: string,
	originalUrl: string,
	path: string,
	protocol: string,
	route: any,
	secure: boolean,
	stale: boolean,
	subdomains: {string},
	xhr: boolean,
	res: res
}

export type res = {
	status: (code: number) -> res,
	send: (body: string? | {[number | string]: any}? | buffer?) -> res,
	json: (body: {[number | string]: any}) -> res,
	redirect: (url: string) -> res,
	set: (field:string, value:string) -> res,
	req: req
}

export type reqm = typeof(
	setmetatable({}, {
		__index = {} :: req,
		__newindex = function(_:any, key:any, value:any)

		end,
	})
)

export type resm = typeof(
	setmetatable({}, {
		__index = {} :: res,
		__newindex = function(_:any, key:any, value:any)

		end,
	})
)

export type route = {
	callback: (req: reqm, res: resm, next: () -> nil) -> nil,
	ext: {
		["method"]: string?,
		["routes"]: string?,
		[string]: string
	}
}

export type routeCallback = (req: reqm, res: resm, next: () -> nil) -> nil
export type methodMiddleware = (route: string, callback: routeCallback) -> { route }
export type middleware = (callback: routeCallback) -> nil?

export type luexpTbl = {}
export type luexpApp = {
	listen: (id: string?, callback: (url: string) -> any?) -> nil?,
	get: methodMiddleware,
	post: methodMiddleware,
	put: methodMiddleware,
	delete: methodMiddleware,
	trace: methodMiddleware,
	patch: methodMiddleware,
	options: methodMiddleware,
	use: middleware
}

export type luexpMetaTbl = typeof(setmetatable({}::{

}, {}::{
	__call: (...any?) -> luexpApp,
	__index: luexpTbl
}))

return {}
