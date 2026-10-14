--- A stable version resolves to its prebuilt archive, which mise downloads,
--- verifies against the published sha256 and extracts. A `ref:` version
--- returns no url: nothing is downloaded and PostInstall clones the ref.
local util = require("util")

function PLUGIN:PreInstall(ctx)
    local version = ctx.version
    if util.git_ref(version) ~= nil then
        return { version = version }
    end

    for _, info in ipairs(util.stable_releases()) do
        if info.version == version then
            -- Every official stable archive ships a sha256; fail closed rather
            -- than install unverified bits.
            if info.sha256 == nil or info.sha256 == "" then
                error("flutter-git: missing sha256 for Flutter archive " .. info.archive)
            end
            return {
                version = version,
                url = util.releases_base_url() .. "/" .. info.archive,
                sha256 = info.sha256,
            }
        end
    end

    local p = util.platform()
    error(
        "flutter-git: no stable Flutter release '" .. version .. "' for " .. p.os .. "/" .. p.arch
            .. "; for a custom build use 'ref:<commit|branch|tag>'"
    )
end
