local args = {...}
local shell = table.remove(args, 1)
local packageSys = kernel.package

local results = {}
local passed = 0
local failed = 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        results[#results + 1] = "[PASS] " .. name
    else
        failed = failed + 1
        results[#results + 1] = "[FAIL] " .. name .. " -> " .. tostring(err)
    end
end

test("import global init package", function()
    local mod = packageSys.import("pkgplus_smoke")
    assert(type(mod) == "table", "expected table module")
    assert(mod.name == "pkgplus_smoke", "unexpected module name")
    assert(mod.sum == 5, "nested import add failed")
    assert(mod.msg == "smoke-ok", "nested import message failed")
end)

test("cache returns same table", function()
    local a = packageSys.import("pkgplus_smoke")
    local b = packageSys.import("pkgplus_smoke")
    assert(a == b, "expected cached reference equality")
end)

test("manifest.slt exports package", function()
    local mod = packageSys.import("pkgplus_exports")
    assert(type(mod) == "table", "expected exports table")
    assert(type(mod.tool) == "table", "missing tool export")
    assert(type(mod.meta) == "table", "missing meta export")
    assert(mod.tool.ping() == "pong", "tool export failed")
    assert(mod.meta.version == "1.0.0", "meta export failed")
end)

local summary = ("packageplus tests: %d passed, %d failed"):format(passed, failed)
results[#results + 1] = summary
if failed > 0 then
    return table.concat(results, "\n") .. "\n"
end
return table.concat(results, "\n") .. "\n"
