-- simple Github API
local fs = require("filesystem")
local classes = require("classes")
local internet = require("internet")
local JSON = require("json")
local GitHub = {}
-- endpoints
local LIST_ENDPOINT = "https://api.github.com/repos/%s/%s/contents/%s?ref=%s"
local DOWNLOAD = "https://raw.githubusercontent.com/%s/%s/%s/%s"
-- more to be added
-- helper
local function makeTree(data)
    local node = {}
    for i=1,#data do
        local cur = data[i]
        if cur.type == "file" then
            node[cur.name] = cur.download_url
        else
            node[cur.name] = {}
        end
    end
    return data
end
local function buildTree(user,repo,branch,start)
    local function list(path)
        local handle = internet.request(LIST_ENDPOINT:format(user,repo,path,branch))
        if not handle then
            return nil
        end
        -- read contents
        local data = handle:read(math.huge)
        handle:close()
        return JSON.decode(data)
    end
    -- start recursive search
    start = start or ""
    -- list all first order files
    local listed = list(start)
    if not listed then
        return nil
    end
    local node = makeTree(listed)
    for n,item in pairs(node) do
        if type(item) == "table" then
            node[n] = buildTree(user,repo,branch,start.."/"..n)
        end
    end
    return node
end
-- main class
local Repo = classes.create("GithubRepo")
function Repo:constructor(user,repo,branch)
    -- first validate this path
    local handle = internet.request(LIST_ENDPOINT:format(user,repo,"",branch))
    if not handle then
        error(("Invalid Repo:%s/%s/%s"):format(user,repo,branch),2)
    end
    -- dont waste it
    local data = handle:read(math.huge)
    handle:close()
    -- parse
    local raw = JSON.decode(data)
    -- valid
    return setmetatable({user=user,repo=repo,branch=branch,tree=makeTree(raw)})
end
function Repo:list(path)
    -- break it up
    local parts = fs.splitPath(path)
    -- check for caching
    local node = self.tree
    local lastnode
    for i=1,#parts do
        local cur = parts[i]
        lastnode = node
        node = node[cur]
        if not node then
            break
        end
    end
    if not node then
        -- list it
        local handle = internet.request(LIST_ENDPOINT:format(self.user,self.repo,path,self.branch))
        if not handle then
            error(("no such path %s in %s/%s/%s"):format(path,self.user,self.repo,self.branch))
        end
        -- decode and push to tree
        local data = handle:read(math.huge)
        handle:close()
        local raw = JSON.decode(data)
        local newnode = makeTree(raw)
        -- find it's spot
        local rebuilt = ""
        for i=1,#parts do
            local cur = parts[i]
            rebuilt = rebuilt.."/"..cur
            lastnode = node
            node = node[cur]
            if not node then
                node = fs.simplify(rebuilt) == path and newnode or self:list(fs.simplify(rebuilt))
                lastnode[cur] = node
            end
        end
        return newnode
    else
        return node
    end
end
function Repo:makeTree()
    self.tree = buildTree(self.user,self.repo,self.branch,"")
end
GitHub.Repo = Repo
return GitHub