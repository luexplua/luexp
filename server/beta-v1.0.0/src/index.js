import express from "express";
import chalk from "chalk";
import fs from "fs";
import EventEmitter from "events";
import config from "../config.json" with { type: "json" };
import { v4 as uuidv4 } from "uuid";
import url, { fileURLToPath } from "url";
import path, { dirname } from 'path';
import WebSocket, { WebSocketServer } from "ws";
import bytes from "bytes";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const publicDir = path.join(__dirname, '../public');
const errorLogsDir = path.join(__dirname, '../error_logs');

const { port, hostData, denyNonLuexpRequests, restrictedIds, restrictedRobloxIds, hostVersion, incomingLimit, onStartWarnings } = config;
const luexpTag = chalk.magenta("[Luexp] ");

const incomingLimitBytes = bytes(incomingLimit);

const protocol = hostData.useSSL ? "https" : "http";
const host = `${protocol}://${hostData.host}`;
const fullUrl = hostData.port ? `${host}:${hostData.port}/` : `${host}/`;

const app = express();
const v2 = express.Router();
const socketProxy = express.Router();
const eventEmitter = new EventEmitter();

const data = {};
const sockets = {};

function generateRandomString(length, charset) {
    const defaultCharset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    const chosenCharset = charset || defaultCharset;
    let result = '';
    const charsetLength = chosenCharset.length;

    for (let i = 0; i < length; i++) {
        const randomIndex = Math.floor(Math.random() * charsetLength);
        result += chosenCharset[randomIndex];
    }

    return result;
}

function isUserAgentRoblox(userAgent) {
    const regex = /RobloxStudio\/[^ ]+ RobloxApp\/[^ ]+ \(.*\)/;
    if (userAgent === "Roblox/Linux") {
        return [true, "server"];
    } else if (regex.test(userAgent)) {
        return [true, "studio"];
    }
    return [false, "none"];
}

function writeNewErrorLog(content) {
    return new Promise((resolve, reject) => {
        try {
            const now = new Date();
            const datePart = now.toISOString().replace(/[-:.TZ]/g, '');
            const name = `/err-${datePart}.txt`;

            fs.writeFile(path.join(errorLogsDir, name), content, (err) => {
                if (err) {
                    reject([false, err]);
                } else {
                    resolve([true, name]);
                }
            });
        } catch (err) {
            reject([false, err]);
        }
    });
}

function routeHandler(req, res) {
    const serverId = req.params.server;
    const server = data[serverId];
    if (!server) {
        return res.status(404).sendFile(path.join(publicDir, '404ClientNotFound.json'));
    }
    const eventName = `endpointVisited-${serverId}`;
    const requestId = uuidv4();
    const requestData = {
        req: {
            // req.app should be added by the client, not server.
            baseUrl: req.baseUrl,
            body: req.body,
            cookies: req.cookies,
            fresh: req.fresh,
            headers: req.headers,
            host: req.host,
            hostname: req.hostname,
            ip: req.ip,
            ips: req.ips,
            method: req.method,
            originalUrl: req.originalUrl,
            // req.params should be added by the client, not server.
            path: req.path,
            protocol: req.protocol,
            // req.res should be added by the client, not server.
            route: req.route,
            secure: req.secure,
            signedCookies: req.signedCookies,
            stale: req.stale,
            subdomains: req.subdomains,
            xhr: req.xhr
            // methods should be added by the client, not server.
        },
        res: {
            // res.app should be added by the client, not server.
            // res.headersSent should be added by the client, not server.
            // res.req should be added by the client, not the server.
            // methods should be added by the client, not the server.
        },
        requestId: requestId
    };

    server.requests[requestId] = {
        req: req,
        res: res,
        requestId: requestId
    };

    server.info.incomingMB += req.dataSize
    server.info.requestCount += 1

    res.set("X-Powered-By", "luexp")
    eventEmitter.emit(eventName, requestData);
}

async function writeNewSocket(req, res) {
    const socketId = generateRandomString(6);
    const host = req.query.host
    const auth = req.query.authorization
    const ip = req.headers['x-forwarded-for'] || req.ip
    try {

        const ws = new WebSocket(host);
        let data = {}

        data["WebSocket"] = ws
        data["Active"] = false
        data["Poll"] = []

        sockets[socketId] = data
        data = sockets[socketId]

        ws.on('ping', () => ws.pong());

        ws.on('open', () => {
            data["Active"] = true
            console.log(luexpTag + chalk.green(`SocketProxy opened @${host} by ${ip}`));
        });

        ws.on('message', (received) => {
            data.Poll.push(received.toString("utf-8"))
        });

        ws.on('close', (code) => {
            console.log(luexpTag + chalk.yellow(`Socket Proxy closed @${host} w/ code ${code}`))
            delete sockets[socketId]
        });

        ws.on('error', (err) => {
            console.error('WebSocket error:', err);
        });

        res.status(201)
        res.json({
            "error": null,
            "message": {
                "socketId": socketId
            },
            "logging": [

            ]
        })

        setTimeout(() => {
            if (sockets[socketId]) {
                sockets[socketId].WebSocket.close()
            }
        }, 43200000)
    } catch (error) {
        let [success, response] = await writeNewErrorLog(`Internal fault while creating endpoint\n\n${error}`)
        let errorReported = success;
        let errorData = {
            "error": "INTERNAL_ERROR",
            "message": "An unknown error occured! We are looking into this issue.",
            "logging": [
                { "type": "warn", "message": `Server fault while creating an server! Error Message: ${error}.` },
            ]
        }
        if (errorReported) {
            errorData.logging.push({ "type": "warn", "message": "We have reported this error." })
            console.log(luexpTag + chalk.red(`Error Reported at ${response}`))
        }
        res.status(500).json(errorData);
    }
}

async function writeNewEndpoint(req, res) {
    const server = req.params.server;
    const invokeError = req.query.invokeError;
    const sendCreated = req.query.sendCreated;

    if (!server || server == "") {
        res.status(400).json({
            "error": "INVALID_SERVER_NAME",
            "message": "Invalid Server Name (must be a string and cant be empty)",
            "logging": [
                { "type": "error", "message": "Invalid Server Name (must be a string and cant be empty)" }
            ]
        })
    }

    if (restrictedIds.includes(server.toLowerCase())) {
        return res.status(403).json({
            "error": "RESTRICTED_SERVER_NAME",
            "message": `\`${server}\` isnt an allowed id.`,
            "logging": [
                { "type": "error", "message": `\`${server}\` isnt an allowed id.` }
            ]
        })
    }

    if (data[server]) {
        return res.status(409).json({
            "error": "SERVER_ID_USED",
            "message": `\`${server}\` is already used, Please wait a few minutes if this is a mistake.`,
            "logging": [
                { "type": "error", "message": `\`${server}\` is already used, Please wait a few minutes if this is a mistake.` }
            ]
        })
    }

    const url = `${fullUrl}${server}`;
    const auth = uuidv4();
    const socketUrl = `${fullUrl}sockets/${server}`;
    const [IsRoblox, Type] = isUserAgentRoblox(req.headers["user-agent"])

    try {
        let logging = [];

        onStartWarnings.map((value) => {
            logging.push({ type: "warn", message: value })
        })

        if (invokeError) {
            throw "Invoked Error"
        }

        if (sendCreated) {
            res.status(201)
        }

        data[server] = {
            "auth": auth,
            "requests": {},
            "info": {
                "roblox-Id": req.headers["roblox-id"],
                "requestCount": 0,
                "incomingMB": 0
            },
        }

        console.log(luexpTag + chalk.green(`Created new endpoint (${url}) with WebSocket (${socketUrl}). By Roblox: ${IsRoblox}, Type: ${Type}`))

        res.set("Upgrade", "websocket")
        res.set("Connection", "Upgrade")

        res.json({
            "error": null,
            "message": {
                "url": url,
                "auth": auth,
                "websocket": socketUrl
            },
            "logging": logging
        })
    } catch (error) {
        let [success, response] = await writeNewErrorLog(`Internal fault while creating endpoint\n\n${error}`)
        let errorReported = success;
        let errorData = {
            "error": "INTERNAL_ERROR",
            "message": "An unknown error occured! We are looking into this issue.",
            "logging": [
                { "type": "warn", "message": `Server fault while creating an server! Error Message: ${error}.` },
            ]
        }
        if (errorReported) {
            errorData.logging.push({ "type": "warn", "message": "We have reported this error." })
            console.log(luexpTag + chalk.red(`Error Reported at ${response}`))
        }
        res.status(500).json(errorData);
    }
}

app.disable('x-powered-by');

app.use((req, res, next) => {
    let data = '';
    let dataLength = 0;
    let dead = false

    req.on('data', chunk => {
        dataLength += chunk.length;

        if (dataLength > incomingLimitBytes) {
            res.status(413).json({
                "error": "PAYLOAD_TOO_LARGE",
                "message": `Payload is larger than ${incomingLimit}.`,
                "logging": [
                    { "type": "error", "message": `Payload is larger than ${incomingLimit}.` }
                ]
            });
            req.connection.destroy();
            dead = true;
            return;
        }

        data += chunk;
    });

    req.on('end', () => {
        if (!dead) {
            req.body = data;
            req.dataSize = dataLength
            next();
        }
    });

    req.on('error', err => {
        console.error('Error reading request body:', err);
        res.status(500).send('Error reading request body');
    });
});

v2.use((req, res, next) => {
    if ((req.headers["x-luexp-version"] == undefined && denyNonLuexpRequests == true) || (req.headers["roblox-id"] && restrictedRobloxIds.includes(parseInt(req.headers["roblox-id"])))) {
        return res.status(401).json({
            "error": "DENIED",
            "message": "You cannot use Luexp!",
            "logging": [
                { "type": "error", "message": "You are not allowed to use Luexp!" }
            ]
        })
    } else {
        next()
    }
})

v2.post("/server/:server", writeNewEndpoint)
v2.delete("/server/:server", (req, res) => {
    const server = data[req.params.server];
    if (!server) return res.status(404).sendFile(path.join(publicDir, '404ClientNotFound.json'));
    if (server.auth !== req.headers.authorization) return res.status(401).json({
        "error": "DENIED",
        "message": "Unauthorized for this action!",
        "logging": []
    });

    delete data[req.params.server];
    res.status(200).json({
        "error": null,
        "message": "Removed server.",
        "logging": []
    })
})

socketProxy.use(express.json())
socketProxy.use('/sockets/:socketId', (req, res, next) => {
    const socketId = req.params.socketId;
    const socketData = sockets[socketId];
    if (socketData) {
        req.socketData = socketData;
        next();
    } else {
        return res.status(404).json({
            "error": "UNKNOWN_SOCKET_ID",
            "message": `${socketId} doesnt exist.`,
            "logging": [
                { "type": "error", "message": `${socketId} doesnt exist in SocketProxy!` }
            ]
        })
    }
})

// get responses
socketProxy.patch('/sockets/:socketId', (req, res) => {
    if (req.body && req.headers["content-type"] === "application/json") {
        req.body = JSON.parse(req.body)
        for (let i = 0; i < req.body.length; i++) {
            const bufferData = Buffer.from(JSON.stringify(req.body[i]));
            req.socketData.WebSocket.send(bufferData);
        }
    }

    res.status(200)
    res.json({
        "error": null,
        "message": req.socketData.Poll,
        "logging": []
    })
    req.socketData.Poll = []
});

// delete socket
socketProxy.delete('/sockets/:socketId', (req, res) => {
    req.socketData.WebSocket.terminate();
    delete sockets[req.params.socketId];
    res.status(200).json({
        "error": null,
        "message": "Closed Socket",
        "logging": []
    })
});

// new socket
socketProxy.post('/new', writeNewSocket);

app.get('/robots.txt', (req, res) => {
    res.sendFile(path.join(publicDir, "robots.txt"))
})

app.get('/humans.txt', (req, res) => {
    res.sendFile(path.join(publicDir, "humans.txt"))
})

app.all(["/sockets/:socketId", "/sockets"], (req, res) => {
    res.status(426).json({
        error: "UPGRADE_TO_WEBSOCKET",
        message: "Upgrade to WebSocket.",
        logging: [
            {
                type: "warn",
                message: "Client attempted to access a WebSocket endpoint using HTTP. Upgrade to WS/WSS is required."
            }
        ]
    });
});

app.use("/luexp/v2", v2);
app.use("/socketProxy", socketProxy);

app.all(["/:server", "/:server/*xd"], routeHandler);

const server = app.listen(port, () => {
    eventEmitter.setMaxListeners(0);

    console.log(luexpTag + chalk.cyan(`Running Luexp Server V${hostVersion}.`));
    console.log(luexpTag + chalk.cyan(`Listening on http://localhost:${port}`));
});

const wss = new WebSocketServer({ noServer: true });

const interval = setInterval(() => {
    wss.clients.forEach((ws) => {
        if (ws.isAlive === false) {
            return ws.terminate();
        }
        ws.isAlive = false;
        ws.ping();
    });
}, 30000); 

server.on('upgrade', (request, socket, head) => {
    const pathname = new URL(request.url, `http://${request.headers.host}`).pathname;

    const match = pathname.match(/^\/sockets\/(.+)$/);
    if (match) {
        const socketId = match[1];

        if (data[socketId]) {
            wss.handleUpgrade(request, socket, head, (ws) => {
                wss.emit('connection', ws, request, socketId);
            });
        } else {
            console.log(luexpTag + chalk.yellow("Client attempted to connect to a unknown socket."))
            socket.destroy();
        }
    } else {
        socket.destroy();
    }
});

wss.on('connection', (ws, request, socketId) => {
    const queryParams = url.parse(request.url, true).query;
    const ip = request.socket.remoteAddress;
    const server = data[socketId]
    const auth = request.headers["authorization"] || queryParams["authorization"]

    if (auth !== server.auth) {
        return ws.close(1008, 'Unauthorized');
    }

    console.log(luexpTag + chalk.green(`${ip} Connected at ${socketId}`))

    eventEmitter.on(`endpointVisited-${socketId}`, (data) => {
        ws.send(JSON.stringify(data))
    });

    ws.on('pong', () => { ws.isAlive = true; });

    ws.on('message', (message) => {
        try {
            const jsonString = message.toString();
            const requestData = JSON.parse(jsonString);
            const inputType = requestData.inputType;

            let requestResponse = {}

            if (inputType === undefined) {
                throw "InputType is missing"
            }

            if (inputType === "CLOSE") {
                ws.close();
                console.log("closed.")
                delete data[socketId];
                console.log(data)
                return
            }

            if (requestData.responseData !== undefined && requestData.responseId !== undefined) {

                const responseId = requestData.responseId;
                const responseData = requestData.responseData;
                const request = server.requests[responseId];

                if (!request) {
                    throw `Request doesnt exist at ${responseId}`
                }

                const res = request.res
                const req = request.req

                const status = responseData.status;
                let body = responseData.body;
                const headers = responseData.headers

                if (inputType === "RESPOND") {
                    if (!status) {
                        throw "Status is missing"
                    }

                    if (headers) {
                        for (let index in headers) {
                            res.set(index, headers[index]);
                        }
                    }

                    res.status(status)

                    if (body) {
                        if (typeof(body) == "object") {
                            if (body.t == "buffer") {
                                body = Buffer.from(body.base64, "base64");
                            }
                        }
                        res.send(body)
                    } else {
                        res.end()
                    }

                    requestResponse = {
                        error: null,
                        message: `Responded to request #${responseId}`
                    }
                } else if (inputType === "REDIRECT") {
                    if (!status) {
                        throw "Status is missing"
                    }

                    res.redirect(body)
                }

                delete server.requests[responseId];

                requestResponse = {
                    error: null,
                    message: `Responded to request #${responseId}`
                }
            } else {
                throw "Invalid Format"
            }

            ws.send(JSON.stringify(requestResponse));
        } catch (error) {
            console.log(`invalid ${error} ${message}`)
            ws.send(JSON.stringify({
                error: "INVALID_JSON",
                message: `Provided JSON is invalid: ${error}`,
                logging: [
                    { type: "warn", message: "Client sent invalid json to server." }
                ]
            }));
        }
    });
});