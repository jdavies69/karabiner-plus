#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_name="Karabiner+"
product_name="KarabinerPlusApp"
bundle_root="${repo_root}/build/${app_name}.app"
contents_dir="${bundle_root}/Contents"
macos_dir="${contents_dir}/MacOS"
resources_dir="${contents_dir}/Resources"
plist_source="${repo_root}/Sources/KarabinerPlusApp/Info.plist"
icon_source="${repo_root}/Assets/KarabinerPlus.icns"
release_binary=""
plistbuddy="/usr/libexec/PlistBuddy"
build_commit="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
build_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
build_number="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
build_date="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cd "${repo_root}"

swift build -c release --product "${product_name}"

if [[ -x ".build/release/${product_name}" ]]; then
  release_binary=".build/release/${product_name}"
elif [[ -x ".build/arm64-apple-macosx/release/${product_name}" ]]; then
  release_binary=".build/arm64-apple-macosx/release/${product_name}"
else
  release_binary="$(find .build -type f -path "*/release/${product_name}" -perm -u+x | head -n 1 || true)"
fi

if [[ -z "${release_binary}" || ! -x "${release_binary}" ]]; then
  echo "Could not find a release binary for ${product_name} under .build." >&2
  exit 1
fi

rm -rf "${bundle_root}"
mkdir -p "${macos_dir}" "${resources_dir}"

install -m 755 "${release_binary}" "${macos_dir}/${product_name}"
cp "${plist_source}" "${contents_dir}/Info.plist"
cp "${icon_source}" "${resources_dir}/KarabinerPlus.icns"

"${plistbuddy}" -c "Set :CFBundleVersion ${build_number}" "${contents_dir}/Info.plist"
"${plistbuddy}" -c "Set :KarabinerPlusBuildBranch ${build_branch}" "${contents_dir}/Info.plist"
"${plistbuddy}" -c "Set :KarabinerPlusBuildCommit ${build_commit}" "${contents_dir}/Info.plist"
"${plistbuddy}" -c "Set :KarabinerPlusBuildDate ${build_date}" "${contents_dir}/Info.plist"
"${plistbuddy}" -c "Set :KarabinerPlusSourcePath ${repo_root}" "${contents_dir}/Info.plist"

chmod +x "${macos_dir}/${product_name}"

echo "Created ${bundle_root}"
