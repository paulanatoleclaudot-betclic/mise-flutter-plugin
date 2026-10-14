--- vfox plugin metadata. mise detects a vfox plugin by this file + hooks/*.lua,
--- and runs the hooks itself, so the plugin works on macOS, Linux and Windows.
PLUGIN = {}

PLUGIN.name = "flutter-git"
PLUGIN.version = "0.2.0"
PLUGIN.description = "Flutter stable releases and custom builds from a git ref (commit, branch, tag, fork or mirror)"
PLUGIN.homepage = "https://github.com/paulanatoleclaudot-betclic/mise-flutter-plugin"
PLUGIN.license = "MIT"
PLUGIN.minRuntimeVersion = "0.3.0"

PLUGIN.legacyFilenames = { ".flutter-version" }
