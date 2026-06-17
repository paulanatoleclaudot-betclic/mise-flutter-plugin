# mise-flutter-plugin

A [mise](https://mise.jdx.dev) plugin for [Flutter](https://flutter.dev) that installs
**official stable releases** *and* **custom builds straight from a git commit** — including
from a fork or an internal mirror.

This is the standalone version of the change proposed in
[jdx/mise#10501](https://github.com/jdx/mise/pull/10501). The mise maintainer preferred not to
carry Flutter git-build support in core, so it lives here as a custom plugin instead.

## Why

The built-in `flutter` registry entry only resolves official **stable releases** from prebuilt
archives. There's no way to say "install Flutter at this commit" or "install Flutter from our
internal mirror" — which is exactly what we need to pin a custom toolchain in CI.

This plugin keeps the existing behaviour (stable releases, downloaded as the prebuilt SDK archive
and verified against the `sha256` in the releases JSON) and **additionally** supports arbitrary
git builds.

## Requirements

- `git`, `curl`, `tar`/`unzip`, and a sha256 tool (`sha256sum` or `shasum`) — all standard on
  macOS/Linux CI images.
- `jq` — used to parse the releases metadata. If it isn't on `PATH`, the plugin downloads a
  pinned-arch binary into `lib/.jq` automatically.

## Install

This plugin replaces the default `flutter` backend as soon as a plugin named `flutter` is
installed:

```sh
mise plugins install flutter https://github.com/paulanatoleclaudot-betclic/mise-flutter-plugin.git
```

To pin it for a project, add it to `mise.toml`:

```toml
[plugins]
flutter = "https://github.com/paulanatoleclaudot-betclic/mise-flutter-plugin.git"
```

For local development of the plugin itself:

```sh
mise plugins link flutter /path/to/mise-flutter-plugin
```

## Usage

### Official stable releases (unchanged)

```sh
mise use -g flutter@3.22.1   # a specific stable version
mise use -g flutter@latest   # the latest stable version
mise ls-remote flutter       # list available stable versions
```

Releases are downloaded from the prebuilt archive and verified against the `sha256` published in
Flutter's `releases_<os>.json`.

### Custom builds (git commit / branch / tag)

A custom build is installed by cloning the Flutter repo, checking out the requested ref, and
running `flutter --version` once to download the matching Dart SDK + engine artifacts.

```sh
mise use -g flutter@ref:abcdef1234567890abcdef1234567890abcdef12   # a commit
mise use -g flutter@ref:master                                     # a branch tip
mise use -g flutter@ref:3.22.1                                     # a tag
```

`ref:` is mise's [ref syntax](https://mise.jdx.dev/dev-tools/#tool-version-syntax) for "build from
source at this git ref".

### Fork / internal mirror

The `remote` tool option (alias `url`) points the git path at a fork or internal mirror. Setting it
forces the git path even for a plain version request, so the version is interpreted as a git ref:

```toml
[tools]
flutter = { version = "ref:abcdef1234567890abcdef1234567890abcdef12", remote = "https://git.internal.example/flutter.git" }
```

```sh
mise use 'flutter[remote=https://git.internal.example/flutter.git]@ref:<sha>'
```

## Configuration

| Option / env var           | Effect                                                                                          |
| -------------------------- | ----------------------------------------------------------------------------------------------- |
| `remote` (alias `url`)     | Tool option: clone from this repo instead of `github.com/flutter/flutter`. Forces the git path. |
| `FLUTTER_STORAGE_BASE_URL` | Mirror for the release archives/metadata (default `https://storage.googleapis.com`).            |

`install_env` is honoured for git/`flutter --version` subprocesses (mise exports it into the
plugin's environment), so proxy settings work:

```toml
[tools]
flutter = { version = "latest", install_env = { HTTPS_PROXY = "http://proxy.example" } }
```

## How it works

| Request                          | Path                                                                                        |
| -------------------------------- | ------------------------------------------------------------------------------------------- |
| `flutter@<version>`              | Find the archive for this version + arch, download, verify sha256, extract, `flutter --version`. |
| `flutter@ref:<commit\|branch\|tag>` | Clone `remote`, check out the ref, `flutter --version` (first-run downloads Dart SDK + engine). |
| `flutter[remote=...]@<ref>`      | Same git path, against the custom remote.                                                   |

`bin/list-all` lists official **stable** versions only. Beta/dev channels are reachable explicitly
via `flutter@ref:beta` etc.

## License

MIT — see [LICENSE](./LICENSE).
