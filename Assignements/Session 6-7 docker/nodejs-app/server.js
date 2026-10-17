// Node.js Hello World - Kiran N (Roll No: 10446)
const http = require("http");
const PORT = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/html" });
  res.end("<h1>Hello World from Node.js!</h1><p>Kiran N - Roll No: 10446</p>");
});

server.listen(PORT, () => console.log(`Node.js app listening on port ${PORT}`));
