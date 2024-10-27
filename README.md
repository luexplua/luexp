# luexp
Luexp is a web framework for Roblox LuaU, inspired by [Express.js](https://github.com/expressjs/express). It’s designed specifically for the Roblox environment to make creating web APIs easier and more intuitive.

## Table of Contents
- [Introduction](#luexp)
- [Getting Started](#getting-started)
- [Installation](#installation)
- [Features](#features)
- [Performance](#Performance)
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

## Performance

We conducted a series of performance benchmarks on both versions of the API under identical conditions, utilizing the same environment for all tests. Each API was subjected to a workload of **1,000 requests** with a concurrency level set to **100**.

The results demonstrated that **v2** exhibits an average response time improvement of approximately **96.23%** compared to **v1**. This substantial enhancement highlights the efficiency of the new implementation in handling high-frequency requests:

![image](https://github.com/user-attachments/assets/1e6b413d-ab1d-4090-8f9d-847fd3ef262c)

In contrast, when evaluating the performance with larger data payloads of **5 MB** across **10 requests**, our findings indicated that **v2** performed **37.48% slower** than **v1** in terms of average response time. This discrepancy suggests that while the new API excels in handling a higher volume of smaller requests, it may encounter challenges with larger data transmissions:

![image](https://github.com/user-attachments/assets/0976d358-8ff8-458d-b0df-b55d81245da1)

---

### Key Observations
- All benchmarks were executed in a controlled environment to ensure comparability, focusing solely on the variations introduced by the different API versions.

---

## Contributing
Contributions are always welcome! If you have a bug fix, feature suggestion, or improvement, feel free to submit a pull request or open an issue. Every contribution helps make Luexp better for everyone.

## Contact
Have questions or suggestions? Feel free to reach out via email at [luexp@perox.dev](mailto:luexp@perox.dev).

## License
Luexp is open-source software licensed under the [MIT License](https://github.com/czctus/luexp/blob/main/LICENSE).
