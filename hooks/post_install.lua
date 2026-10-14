--- Custom builds: clone the requested ref into the install dir, then run
--- `flutter --version` once so the Dart SDK and engine artifacts are fetched.
---
--- Every command runs with `cwd` set instead of a path argument, so no install
--- path is ever quoted for `sh -c` / `cmd /C` (Windows paths contain spaces).
local cmd = require("cmd")
local file = require("file")
local util = require("util")

local function run(command, cwd)
    local ok, out = pcall(cmd.exec, command, { cwd = cwd })
    if not ok then
        error("flutter-git: `" .. command .. "` failed: " .. tostring(out))
    end
    return out
end

local function try(command, cwd)
    return (pcall(cmd.exec, command, { cwd = cwd }))
end

--- Treeless fetch (commits + tags, trees/blobs on demand) instead of
--- `--depth 1`: Flutter derives its version from `git describe --tags`, and a
--- shallow checkout reports `0.0.0-unknown`, which breaks pub's
--- `environment: flutter:` constraints.
local function clone(ref, dir, remote)
    print("flutter-git: cloning " .. remote .. " @ " .. ref)
    run("git init -q", dir)
    run("git config core.longpaths true", dir)
    run("git remote add origin " .. remote, dir)
    if try("git fetch -q --filter=tree:0 --tags origin " .. ref, dir) then
        run("git -c advice.detachedHead=false checkout -q FETCH_HEAD", dir)
        return
    end
    -- Abbreviated SHAs (and refs a server won't serve directly) need the full
    -- ref list before they can be resolved.
    print("flutter-git: direct fetch of '" .. ref .. "' failed; fetching all refs")
    run("git fetch -q --filter=tree:0 --tags origin +refs/heads/*:refs/remotes/origin/*", dir)
    if not try("git -c advice.detachedHead=false checkout -q " .. ref, dir)
        and not try("git -c advice.detachedHead=false checkout -q origin/" .. ref, dir) then
        error("flutter-git: ref '" .. ref .. "' not found in " .. remote)
    end
end

function PLUGIN:PostInstall(ctx)
    local ref = util.git_ref(ctx.runtimeVersion)
    if ref == nil then
        return
    end
    local dir = ctx.rootPath
    if not file.exists(dir) then
        -- No archive was extracted; create the leaf from its parent so the
        -- path never has to be quoted.
        local parent, leaf = dir:match("^(.*)[/\\]([^/\\]+)$")
        run("mkdir " .. leaf, parent)
    end

    clone(ref, dir, util.git_url())

    local flutter = util.is_windows() and "bin\\flutter.bat" or "bin/flutter"
    print("flutter-git: running flutter --version (downloads the Dart SDK + engine on first run)")
    print(run(flutter .. " --version", dir))
end
