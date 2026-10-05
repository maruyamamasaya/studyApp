#!/bin/bash
# Invoke with bash; generated project and verification results stay outside source control.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then echo 'Run on a Mac with full Xcode.' >&2; exit 1; fi
command -v xcodegen >/dev/null || { echo 'Install XcodeGen: brew install xcodegen' >&2; exit 1; }
xcodebuild -version
xcodegen generate
/usr/libexec/PlistBuddy -c 'Print :UIBackgroundModes' Generated/Info.plist
# Explicitly select an installed, available Simulator ID; never guess an iPhone model.
if [[ -z "${1:-}" ]]; then
  xcodebuild -project StudyApp.xcodeproj -scheme StudyApp -showdestinations
  echo 'Run again: bash scripts/verify-mac.sh SIMULATOR_ID' >&2
  exit 2
fi
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/studyapp-verification.XXXXXX")"
echo "Results: $run_dir"
args=(-project StudyApp.xcodeproj -scheme StudyApp -destination "platform=iOS Simulator,id=$1" -derivedDataPath "$run_dir/DerivedData" CODE_SIGNING_ALLOWED=NO)
xcodebuild "${args[@]}" -resolvePackageDependencies 2>&1 | tee "$run_dir/packages.log"
xcodebuild "${args[@]}" build-for-testing 2>&1 | tee "$run_dir/build.log"
xcodebuild "${args[@]}" test-without-building -only-testing:StudyAppTests -parallel-testing-enabled NO -resultBundlePath "$run_dir/Tests.xcresult" 2>&1 | tee "$run_dir/tests.log"
echo 'Confirm 23 tests, 0 failures in tests.log / Tests.xcresult; then run the device checklist.'
echo "Results: $run_dir"
