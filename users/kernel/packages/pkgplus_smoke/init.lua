local util = package.import("./util")

return {
    name = "pkgplus_smoke",
    sum = util.add(2, 3),
    msg = util.message
}
