--- `.flutter-version`: a bare version (or `ref:<x>`) on the first line.
local file = require("file")

function PLUGIN:ParseLegacyFile(ctx)
    local content = file.read(ctx.filepath)
    return { version = (content:match("^%s*(%S+)")) }
end
