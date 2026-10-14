--- `mise ls-remote`: official stable releases only. Beta/master and arbitrary
--- commits are reachable explicitly via `ref:<branch|tag|sha>`.
local util = require("util")

function PLUGIN:Available(ctx)
    local result = {}
    for _, info in ipairs(util.stable_releases()) do
        table.insert(result, { version = info.version })
    end
    return result
end
