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

This is an unsigned public-alpha build.

Karabiner+ is an unofficial companion app for the official Karabiner-Elements app. It does not include the Karabiner keyboard driver.

If macOS blocks the app because it is unsigned, right-click Karabiner+.app and choose Open. For the smoothest public release, future builds should be signed and notarized with an Apple Developer ID.

Source:
https://github.com/jdavies69/karabiner-plus
EOF

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "${release_dir}" "${archive_path}"
rm -rf "${stage_root}"

echo "Created ${archive_path}"
