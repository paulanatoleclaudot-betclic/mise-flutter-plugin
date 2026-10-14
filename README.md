# mise-flutter-plugin

A [mise](https://mise.jdx.dev) plugin for [Flutter](https://flutter.dev) that installs
**official stable releases** *and* **custom builds straight from a git commit**, including
from a fork or an internal mirror. It works on **macOS, Linux and Windows**.

This is the standalone version of the change proposed in
[jdx/mise#10501](https://github.com/jdx/mise/pull/10501). The mise maintainer preferred not to
carry Flutter git-build support in core, so it lives here as a custom plugin instead.

## Why

The built-in `flutter` registry entry only resolves official **stable releases** from prebuilt
archives. There's no way to say "install Flutter at this commit" or "install Flutter from our
internal mirror", which is exactly what we need to pin a custom toolchain in CI.

This plugin keeps the stable-release behaviour (prebuilt SDK archive, verified against the
`sha256` in Flutter's releases JSON) and **additionally** supports arbitrary git builds.

### Why vfox (and not asdf)

The plugin is a [vfox](https://mise.jdx.dev/dev-tools/backends/vfox.html) plugin: Lua hooks
(`metadata.lua` + `hooks/*.lua`) that mise runs itself. mise never runs asdf (bash) plugins on
Windows. It skips `asdf:` tools there, so a bash plugin can't serve a Windows CI runner. With
vfox there is one implementation for every platform.

Earlier versions of this repo were an asdf plugin (`bin/` + `lib/*.bash`). They were removed
rather than kept alongside: mise loads a plugin as vfox as soon as `metadata.lua` exists, so
the bash scripts would have been dead code.

## Requirements

- mise with vfox support (any recent release).
- `git` on `PATH` for `ref:` installs. Nothing else is needed: downloads, checksums and
  extraction are done by mise.

## Install

Register the plugin under a **distinct name**, e.g. `flutter-git`, and pin it to a commit:

```toml
[plugins]
flutter-git = "https://github.com/paulanatoleclaudot-betclic/mise-flutter-plugin.git#<sha>"

[tools]
flutter-git = "ref:27fec0e365a374f1d9c1ffb24b57b4fc69966c9a"
```

Pinning with `#<sha>` makes every machine and CI run use the same plugin code. Without it, mise
installs whatever the default branch points at the time of the first install.

> **Don't name the plugin `flutter`.** A plugin named `flutter` takes over mise's built-in
> `flutter` tool, so every project on the machine that uses `flutter = "x.y.z"` starts going
> through this plugin instead of the core `http:flutter` backend. With a distinct name, both
> coexist: `flutter = "3.47.3"` keeps resolving to `http:flutter` (`mise tool flutter` shows
> `Backend: http:flutter`), and only `flutter-git` uses this plugin.

From the CLI:

```sh
mise plugins install flutter-git https://github.com/paulanatoleclaudot-betclic/mise-flutter-plugin.git
```

For local development of the plugin itself:

```sh
mise plugins link flutter-git /path/to/mise-flutter-plugin
```

## Usage

### Official stable releases

```sh
mise use flutter-git@3.47.3   # a specific stable version
mise use flutter-git@latest   # the latest stable version
mise ls-remote flutter-git    # list available stable versions
```

mise downloads the archive for the current OS/arch and verifies it against the `sha256`
published in Flutter's `releases_<os>.json`.

### Custom builds (git commit / branch / tag)

```sh
mise use flutter-git@ref:27fec0e365a374f1d9c1ffb24b57b4fc69966c9a   # a commit (full or abbreviated)
mise use flutter-git@ref:master                                      # a branch tip
mise use flutter-git@ref:3.47.3                                      # a tag
```

`ref:` is mise's [ref syntax](https://mise.jdx.dev/dev-tools/#tool-version-syntax). The plugin
clones the repo into the install dir, checks out the ref, and runs `flutter --version` once so the
matching Dart SDK and engine artifacts are downloaded. Any failure fails the install.

The clone is **treeless** (`git fetch --filter=tree:0 --tags`), not `--depth 1`. Flutter derives
its version from `git describe --tags`, and a shallow checkout reports `0.0.0-unknown`, which
breaks pub's `environment: flutter:` constraints. A treeless clone of the pinned master commit
reports `3.49.0-0.2.pre` and costs about 100 MB of `.git`.

### Fork / internal mirror

Set Flutter's own `FLUTTER_GIT_URL` through `install_env`:

```toml
[tools]
flutter-git = { version = "ref:<sha>", install_env = { FLUTTER_GIT_URL = "https://git.internal.example/flutter.git" } }
```

vfox install hooks don't receive mise tool options, only `install_env`, so a `remote = "..."`
option would be silently ignored. `FLUTTER_GIT_URL` is also what the installed `flutter` tool
reads to know its upstream, so the plugin and the tool agree.

## Configuration

| Env var                    | Effect                                                                                  |
| -------------------------- | --------------------------------------------------------------------------------------- |
| `FLUTTER_GIT_URL`          | Clone `ref:` builds from this repo instead of `https://github.com/flutter/flutter.git`. |
| `FLUTTER_STORAGE_BASE_URL` | Mirror for the release archives and metadata (default `https://storage.googleapis.com`). |

Both are read from `install_env` or the environment. `install_env` also reaches the `git` and
`flutter --version` subprocesses, so proxy settings work:

```toml
[tools]
flutter-git = { version = "ref:master", install_env = { HTTPS_PROXY = "http://proxy.example" } }
```

`.flutter-version` files are read as legacy version files when mise's
`idiomatic_version_file_enable_tools` setting includes `flutter-git`.

## How it works

| Hook                         | Responsibility                                                                                     |
| ---------------------------- | -------------------------------------------------------------------------------------------------- |
| `hooks/available.lua`        | `ls-remote`: stable versions from `releases_<os>.json`.                                            |
| `hooks/pre_install.lua`      | Plain version → `{version, url, sha256}` (mise downloads, verifies, extracts). `ref:` → no url.    |
| `hooks/post_install.lua`     | `ref:` only: treeless fetch of the ref (falls back to fetching all refs), checkout, `flutter --version`. |
| `hooks/env_keys.lua`         | `PATH += <install>/bin`, `FLUTTER_ROOT = <install>`.                                               |
| `hooks/parse_legacy_file.lua`| `.flutter-version` support.                                                                        |
| `lib/util.lua`               | OS/arch mapping, release metadata, storage and git URLs.                                           |

On Windows, every command runs with its working directory set instead of taking a path argument,
so install paths containing spaces never need quoting for `cmd /C`.

## License

MIT, see [LICENSE](./LICENSE).
