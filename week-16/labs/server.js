// Minimal Node.js server for the multi-stage Dockerfile exercise (Lab 16.1)
// This demonstrates building a Node.js app in one stage and running in another.

const http = require("http");

const PORT = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
    if (req.url === "/healthz") {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ status: "healthy" }));
        return;
    }

    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({
        message: "Hello from the containerized Node.js app!",
        node_version: process.version,
        timestamp: new Date().toISOString()
    }));
});

server.listen(PORT, () => {
    console.log(`Server listening on port ${PORT}`);
});
