#!/usr/bin/env sh
# @file yazi-picker.sh
# @brief Check the portal wrapper without opening a terminal or using the desktop bus.
# @description Run with `sh tests/yazi-picker.sh` to check file, save, directory, cancellation, failure, and shell-safe filename handling.
set -eu

wrapper=$(realpath "$(dirname "$0")/../dot_config/xdg-desktop-portal-termfilechooser/executable_yazi-wrapper.sh")
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export TMPDIR="$tmp" CAPTURE="$tmp/args" SELECTION=selected CWD_SELECTION=current
export PATH="$tmp:$PATH"

cat > "$tmp/foot" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "$@" > "$CAPTURE"
if [ "${MOCK_FAILURE:-0}" = 1 ]; then
    exit 7
fi
for arg do
    case "$arg" in
        --chooser-file=*) printf '%s' "$SELECTION" > "${arg#*=}" ;;
        --cwd-file=*) printf '%s' "$CWD_SELECTION" > "${arg#*=}" ;;
    esac
done
SH
chmod +x "$tmp/foot"
cd "$tmp"

path="$tmp/"'spaces '\'' " $HOME $(touch injected) `touch injected` ; end'
out="$tmp/selection"
for mode in '0 0 0' '1 0 0' '0 0 1'; do
    set -- $mode
    sh "$wrapper" "$@" "$path" "$out" 0
    printf '%s\n' --title 'File picker — Yazi' yazi "--chooser-file=$out" "$path" > "$tmp/expected"
    cmp "$CAPTURE" "$tmp/expected"
    test "$(cat "$out")" = selected
done

test ! -e injected
SELECTION= sh "$wrapper" 0 0 0 "$path" "$out" 0
test ! -s "$out"

SELECTION= sh "$wrapper" 0 1 0 "$path" "$out" 0
test "$(cat "$out")" = current
sh "$wrapper" 0 1 0 "$path" "$out" 0
test "$(cat "$out")" = selected
SELECTION= CWD_SELECTION= sh "$wrapper" 0 1 0 "$path" "$out" 0
test ! -s "$out"

if MOCK_FAILURE=1 sh "$wrapper" 0 1 0 "$path" "$out" 0; then
    printf '%s\n' 'FAIL: terminal failure was ignored' >&2
    exit 1
fi
test -z "$(find "$tmp" -name 'tmp.*' -type f -print)"
printf '%s\n' 'PASS: file, multi-file, save, directory, cancellation, failure and literal filename arguments'
