const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");

const root = __dirname;
const port = Number(process.env.PORT || 8765);
const types = {
	".css": "text/css; charset=utf-8",
	".html": "text/html; charset=utf-8",
	".js": "text/javascript; charset=utf-8",
	".json": "application/json; charset=utf-8",
	".png": "image/png",
	".svg": "image/svg+xml",
};

http.createServer((request, response) => {
	const requestPath = decodeURIComponent(new URL(request.url, `http://${request.headers.host}`).pathname);
	const relative = requestPath.endsWith("/") ? `${requestPath}index.html` : requestPath;
	const filePath = path.resolve(root, `.${relative}`);
	if (!filePath.startsWith(root) || !fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
		response.writeHead(404).end("Not found");
		return;
	}
	response.writeHead(200, { "Content-Type": types[path.extname(filePath)] || "application/octet-stream" });
	fs.createReadStream(filePath).pipe(response);
}).listen(port, "127.0.0.1", () => {
	console.log(`Vector Anomaly website: http://127.0.0.1:${port}`);
});
