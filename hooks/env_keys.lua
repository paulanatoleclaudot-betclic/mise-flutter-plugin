function PLUGIN:EnvKeys(ctx)
    local root = ctx.path
    local sep = RUNTIME.osType == "windows" and "\\" or "/"
    return {
        { key = "FLUTTER_ROOT", value = root },
        { key = "PATH", value = root .. sep .. "bin" },
    }
end
