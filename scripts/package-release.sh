#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plistbuddy="/usr/libexec/PlistBuddy"
dist_dir="${repo_root}/dist"
stage_root="${dist_dir}/stage"

cd "${repo_root}"

./build.sh

version="$("${plistbuddy}" -c "Print :CFBundleShortVersionString" "build/Karabiner+.app/Contents/Info.plist")"
commit="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
release_name="KarabinerPlus-${version}-${commit}-unsigned"
release_dir="${stage_root}/${release_name}"
archive_path="${dist_dir}/${release_name}.zip"

rm -rf "${stage_root}" "${archive_path}"
mkdir -p "${release_dir}"

/usr/bin/ditto "build/Karabiner+.app" "${release_dir}/Karabiner+.app"

cat > "${release_dir}/README-FIRST.txt" <<EOF
Karabiner+ ${version} (${commit})

This is an unsigned, not-notarized alpha build.

Karabiner+ is an unofficial companion app for the official Karabiner-Elements app. It does not include the Karabiner keyboard driver.

What's included:
- first-shortcut wizard
- global and app-specific custom shortcuts
- Right Command launcher sequences from local app history
- visual apply summaries before custom shortcut writes
- local backup restore and undo

macOS Gatekeeper may warn that the developer cannot be verified and may block first launch. Only open this app if you trust this source. For this alpha, the usual workaround is to right-click Karabiner+.app and choose Open. For the smoothest public release, future builds should be signed and notarized with an Apple Developer ID.

Source:
https://github.com/jdavies69/karabiner-plus
EOF

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "${release_dir}" "${archive_path}"
rm -rf "${stage_root}"

echo "Created ${archive_path}"
