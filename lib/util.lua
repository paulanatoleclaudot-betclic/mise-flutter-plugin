--- Shared helpers: platform mapping, release metadata, git refs.
local http = require("http")
local json = require("json")

local util = {}

util.DEFAULT_STORAGE_BASE_URL = "https://storage.googleapis.com"
util.DEFAULT_GIT_URL = "https://github.com/flutter/flutter.git"

--- `ref:<commit|branch|tag>` selects a custom build from git.
function util.git_ref(version)
    if version == nil then
        return nil
    end
    return version:match("^ref:(.+)$")
end

function util.is_windows()
    return RUNTIME.osType == "windows"
end

--- Flutter's names for the current OS and Dart SDK arch.
function util.platform()
    local os_type = RUNTIME.osType
    if os_type == "darwin" then
        os_type = "macos"
    end
    local arch = RUNTIME.archType
    if arch == "amd64" then
        arch = "x64"
    elseif arch ~= "arm64" then
        error("flutter-git: unsupported architecture " .. tostring(arch))
    end
    return { os = os_type, arch = arch }
end

--- Mirror for the release archives/metadata, same layout as storage.googleapis.com.
function util.storage_base_url()
    local base = os.getenv("FLUTTER_STORAGE_BASE_URL")
    if base == nil or base == "" then
        base = util.DEFAULT_STORAGE_BASE_URL
    end
    return (base:gsub("/+$", ""))
end

--- Fork / internal mirror to clone from. Flutter's own variable, so the
--- installed tool agrees with the plugin about where its upstream lives.
function util.git_url()
    local url = os.getenv("FLUTTER_GIT_URL")
    if url == nil or url == "" then
        return util.DEFAULT_GIT_URL
    end
    return url
end

function util.releases_base_url()
    return util.storage_base_url() .. "/flutter_infra_release/releases"
end

function util.fetch_releases(os_name)
    local url = util.releases_base_url() .. "/releases_" .. os_name .. ".json"
    local resp, err = http.get({ url = url })
    if err ~= nil then
        error("flutter-git: failed to fetch " .. url .. ": " .. err)
    end
    if resp.status_code ~= 200 then
        error("flutter-git: failed to fetch " .. url .. ": HTTP " .. resp.status_code)
    end
    return json.decode(resp.body)
end

--- Stable releases for this OS/arch, newest first, one entry per version.
--- macOS lists each version once per arch; Linux/Windows omit dart_sdk_arch
--- on their x64-only archives, so a missing field means x64.
function util.stable_releases()
    local p = util.platform()
    local body = util.fetch_releases(p.os)
    local seen = {}
    local result = {}
    for _, info in ipairs(body.releases) do
        if info.channel == "stable" and (info.dart_sdk_arch or "x64") == p.arch and not seen[info.version] then
            seen[info.version] = true
            table.insert(result, info)
        end
    end
    return result
end

return util
