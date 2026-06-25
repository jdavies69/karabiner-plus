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

chmod +x "${macos_dir}/${product_name}"

echo "Created ${bundle_root}"
