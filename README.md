# luexp
Luexp is a web framework for Roblox LuaU, inspired by [Express.js](https://github.com/expressjs/express). It’s designed specifically for the Roblox environment to make creating web APIs easier and more intuitive.

## Table of Contents
- [Introduction](#luexp)
- [Getting Started](#getting-started)
- [Installation](#installation)
- [Features](#features)
- [Contributing](#contributing)
- [Contact](#contact)
- [License](#license)

## Getting Started
Here’s a quick example to set up your first Luexp application:

```lua
local luexp = require(path.to.luexp)
local app = luexp()

app.get("/", function(req, res)
    res.send("Hello!")
end)

app.listen("example", function(url)
    print(`App listening on {url}!`)
end)
```

## Installation
Download the latest release from [here](#) and place the Luexp module anywhere within your Roblox game files.

## Why Use Luexp?
Luexp brings a familiar Express.js-like syntax to Roblox, simplifying API creation. It’s ideal for developers who:
- Want to structure their code using a web framework approach.
- Need flexible HTTP request handling directly within Roblox LuaU.
- Appreciate an open-source and minimalistic framework tailored for the Roblox environment.

## Features
- **Express 5-based**: Familiar patterns and methods inspired by Express.
- **Roblox-friendly**: Designed specifically for use in Roblox games and projects.
- **Minimalistic & Free**: Lightweight and free to use with no hidden costs.
- **Cross-Compatible**: Works seamlessly with Luexp v1.x projects.
### **Highly improved speed**
We benchmarked both versions, with the same exact setup.
We sent one thousand requests to each in 100 concurrency.

Our results said that v2 is roughly 96.23% faster compared to v1: 

![image](https://github.com/user-attachments/assets/c9348244-e16a-4f17-a6d4-9c4d7e260631)


## Contributing
Contributions are always welcome! If you have a bug fix, feature suggestion, or improvement, feel free to submit a pull request or open an issue. Every contribution helps make Luexp better for everyone.

## Contact
Have questions or suggestions? Feel free to reach out via email at [luexp@perox.dev](mailto:luexp@perox.dev).

## License
Luexp is open-source software licensed under the [MIT License](https://github.com/czctus/luexp/blob/main/LICENSE).
