local signal = require("posix.signal")
local socket = require("socket")

local base_header = "Content-Type: text/html; charset=UTF-8\n"

local status = {
    OK = "HTTP/1.1 200 OK\n"..base_header,
    NOTFOUND = "HTTP/1.1 404 Not Found\n"..base_header.."Content-Length: 2\n\n".."NF"
}

local patterns = {
    METHOD_GET = "GET",
    METHOD_POST = "POST",
    METHOD_PUT = "PUT",
    METHOD_DELETE = "DELETE"
    --TODO: implement all sections
}

local routes = {
    {
        route = "/",
        content = [[<h1>Home</h1>]],
        body = nil
    }
}

local shttp = {
    running = true,

    prepare_contents = function()
        for k, v in pairs(routes) do
            v.body = "Content-Length: "..string.len(v.content).."\n\n"..v.content
        end
    end,

    parse = function(self, data)
        --verify method
        local pattern
        local words = {}
        for k, v in pairs(patterns) do
            if data:find("^"..v) ~= nil then
                pattern = k
                local s
                for s in string.gmatch(data, "%S+") do
                    if s ~= v then
                        table.insert(words, s)
                    end
                end
            end
        end
        return pattern, words
    end,

    get_page = function(self, route)
        for k, v in pairs(routes) do
            if v.route == route then
                return v
            end
        end
        return "notfound"
    end,

    init = function(self, port)
        local server = assert(socket.bind("*", port))
        local ip, port = server:getsockname()

        self:prepare_contents()
        while self.running do
            local client = server:accept()
            client:settimeout(5)

            local pkg, err = client:receive()

            while not err do
                local pattern, words = self:parse(pkg)

                --TODO: For now only look for the method section - GET
                --lot of improvementes to be made
                if pattern == "METHOD_GET" then
                    local render = self:get_page(words[1])
                    if render == "notfound" or render.body == nil then
                        client:send(status["NOTFOUND"])
                    else
                        local str = status["OK"]..render.body
                        client:send(str)
                    end
                end
                pkg, err = client:receive()
            end
            client:close()
        end
        server:close()
    end
}

local function kill(sig)
    shttp.running = false
    return 0
end

signal.signal(signal.SIGINT, kill)

shttp:init(4141)
