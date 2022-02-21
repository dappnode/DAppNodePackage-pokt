const {createReadStream} = require('fs')
const {createServer} = require('http')
const {CUSTOM_UI_HTTP_PORT = 80} = process.env
const HTML_CONTENT_TYPE = 'text/html'

const requestListener = (req, res) => {
  res.writeHead(200, { 'Content-Type': HTML_CONTENT_TYPE })
  createReadStream('index.html').pipe(res)
}

const server = createServer(requestListener)
server.listen(CUSTOM_UI_HTTP_PORT)
