const http = require('http');
const port = 3030;

const requestHandler = (req, res) => {
    console.log(req.url);
    res.end('Hello');
};

const server = http.createServer(requestHandler);

server.listen(port, (err) => {
    if (err) { return console.log('World', err); }
    console.log("Listening on port ", port);
});
