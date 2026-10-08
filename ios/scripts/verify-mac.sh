#!/bin/bash
# Run with bash. Never delete Simulator devices automatically.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin ]] || { echo 'Run on a Mac with full Xcode.' >&2; exit 1; }
command -v xcodegen >/dev/null || { echo 'Install XcodeGen: brew install xcodegen' >&2; exit 1; }
if [[ -z "${1:-}" ]]; then
  echo 'Usage: bash ios/scripts/verify-mac.sh SIMULATOR_ID [StudyAppTests/Class/testMethod ...]' >&2
  echo 'Choose an existing available device: xcrun simctl list devices available' >&2
  exit 2
fi
simulator_id="$1"
shift
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/studyapp-verification.XXXXXX")"
echo "Results: $run_dir"
exec > >(tee "$run_dir/run.log") 2>&1
record_devices() {
  date -u '+%Y-%m-%dT%H:%M:%SZ' > "$run_dir/$1-time.txt"
  ps -axo pid,ppid,command > "$run_dir/$1-processes.txt"
  xcrun simctl --set "$HOME/Library/Developer/XCTestDevices" list devices -j > "$run_dir/$1-devices.json" 2> "$run_dir/$1-devices.err"
}
finish() {
  result=$?
  trap - EXIT
  record_devices after || { echo 'Post-run device inventory failed; do not infer an empty device set.'; [[ "$result" != 0 ]] || result=1; }
  echo "Exit: $result. Results: $run_dir"
  echo 'Confirm test count/failures in Tests.xcresult and process termination; follow README Simulator cleanup rules.'
  exit "$result"
}
trap finish EXIT
git rev-parse HEAD > "$run_dir/commit.txt"
git status --short > "$run_dir/worktree.txt"
printf '%s\n' "$simulator_id" > "$run_dir/simulator.txt"
xcodebuild -version
xcrun simctl list devices available -j > "$run_dir/available-devices.json"
record_devices before
xcodegen generate
/usr/libexec/PlistBuddy -c 'Print :UIBackgroundModes' Generated/Info.plist
args=(-project StudyApp.xcodeproj -scheme StudyApp -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath "$run_dir/DerivedData" CODE_SIGNING_ALLOWED=NO)
test_args=(-only-testing:StudyAppTests)
if [[ "$#" -gt 0 ]]; then
  test_args=()
  for test_name in "$@"; do test_args+=("-only-testing:$test_name"); done
fi
printf '%q ' xcodebuild "${args[@]}" test-without-building "${test_args[@]}" -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -resultBundlePath "$run_dir/Tests.xcresult" > "$run_dir/test-command.txt"
xcodebuild "${args[@]}" -resolvePackageDependencies 2>&1 | tee "$run_dir/packages.log"
xcodebuild "${args[@]}" build-for-testing 2>&1 | tee "$run_dir/build.log"
xcodebuild "${args[@]}" test-without-building "${test_args[@]}" -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -resultBundlePath "$run_dir/Tests.xcresult" 2>&1 | tee "$run_dir/tests.log"
