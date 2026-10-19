#!/usr/bin/env fish
# Run with `fish --no-config tests/screenshot.fish`; capture, selection, notifications and clipboard access are isolated fixtures.

set -l script (path resolve (status dirname)/../dot_local/bin/executable_screenshot)
set -l fish (status fish-path)
set -l tmp (mktemp -d); or exit 1

function cleanup --on-event fish_exit --inherit-variable tmp --description 'Remove the isolated test home and fixtures'
    rm -rf -- "$tmp"
end

set -lx HOME $tmp/home
set -lx XDG_RUNTIME_DIR $tmp/runtime
set -lx PATH $tmp/bin $PATH
set -lx TEST_ROOT $tmp
set -lx CAPTURE_MODE success
set -lx CAPTURE_CONTENT first
set -lx PICKER_MODE success
set -lx QUERY_MODE success
set -lx CLIPBOARD_MODE success
set -lx NOTIFY_MODE success
mkdir -p $HOME/.config/motif/spec $XDG_RUNTIME_DIR $tmp/bin
printf '%s\n' '{"dark":{"primary":"#12ab34"}}' >$HOME/.config/motif/spec/palette.json

printf '%s\n' '#!/bin/sh
if [ "$QUERY_MODE" = error ]; then exit 1; fi
if [ "$QUERY_MODE" = empty ]; then printf "[]\n"; exit 0; fi
case "$2" in
    get_outputs) printf "%s\n" "[{\"name\":\"DP-2\",\"focused\":true}]" ;;
    get_tree) printf "%s\n" "{\"nodes\":[{\"pid\":1,\"visible\":true,\"rect\":{\"x\":10,\"y\":20,\"width\":100,\"height\":80}},{\"pid\":2,\"visible\":false,\"rect\":{\"x\":0,\"y\":0,\"width\":200,\"height\":200}}]}" ;;
    *) exit 1 ;;
esac' >$tmp/bin/swaymsg
printf '%s\n' '#!/bin/sh
printf "%s\n" "$@" > "$TEST_ROOT/slurp-args"
cat > "$TEST_ROOT/presets"
case "$PICKER_MODE" in
    cancel) exit 1 ;;
    empty) exit 0 ;;
    hold) touch "$TEST_ROOT/started"; sleep 1 ;;
esac
printf "10,20 100x80\n"' >$tmp/bin/slurp
printf '%s\n' '#!/bin/sh
printf "%s\n" "$@" > "$TEST_ROOT/grim-args"
for file do :; done
case "$CAPTURE_MODE" in
    fail) exit 2 ;;
    empty) exit 0 ;;
    partial) printf partial > "$file"; exit 2 ;;
esac
printf "%s\n" "$CAPTURE_CONTENT" > "$file"' >$tmp/bin/grim
printf '%s\n' '#!/bin/sh
printf "%s\n" "$@" > "$TEST_ROOT/clipboard-args"
cat > "$TEST_ROOT/clipboard"
case "$CLIPBOARD_MODE" in
    fail) exit 1 ;;
    child) sleep 2 <&0 >/dev/null 2>&1 & ;;
esac' >$tmp/bin/wl-copy
printf '%s\n' '#!/bin/sh
printf "%s\n" "$@" > "$TEST_ROOT/notification"
[ "$NOTIFY_MODE" != fail ]' >$tmp/bin/notify-send
chmod +x $tmp/bin/*

function expect --inherit-variable fish --inherit-variable script --description 'Assert the screenshot exit status without invoking real capture tools' --argument-names expected
    $fish --no-config $script $argv[2..] >$TEST_ROOT/stdout 2>$TEST_ROOT/stderr
    set -l actual $status
    if test $actual -ne $expected
        printf 'FAIL: screenshot %s: expected status %s, got %s\n' "$argv[2..]" $expected $actual >&2
        string collect <$TEST_ROOT/stderr >&2
        exit 1
    end
end

function expect_files --description 'Assert that failed captures did not create or remove saved images' --argument-names expected
    set -l files $HOME/Pictures/Screenshots/*.png
    if test (count $files) -ne $expected
        printf 'FAIL: expected %s images, got %s\n' $expected (count $files) >&2
        exit 1
    end
end

expect 2
expect 2 invalid
expect 2 screen extra
env -u XDG_RUNTIME_DIR $fish --no-config $script screen >/dev/null 2>&1
test $status -ne 0; and test ! -d $HOME/Pictures; or exit 1

mkdir -p $HOME/Pictures
touch $HOME/Pictures/Screenshots
expect 1 screen
test ! -e $tmp/grim-args; or exit 1
rm $HOME/Pictures/Screenshots

for target in window area screen
    expect 0 $target
    grep -Fxq png $tmp/grim-args; or exit 1
    grep -Fxq image/png $tmp/clipboard-args; or exit 1
    cmp (string collect <$tmp/stdout) $tmp/clipboard; or exit 1
    switch $target
        case window area
            grep -Fxq -- -g $tmp/grim-args; or exit 1
            grep -Fxq '10,20 100x80' $tmp/grim-args; or exit 1
            grep -Fxq '#12ab34' $tmp/slurp-args; or exit 1
            grep -Fxq '#00000040' $tmp/slurp-args; or exit 1
            grep -Fxq '#00000000' $tmp/slurp-args; or exit 1
            if test $target = window
                grep -Fxq -- -r $tmp/slurp-args; or exit 1
                test (string collect <$tmp/presets) = '10,20 100x80'; or exit 1
            else
                grep -Fxq -- -d $tmp/slurp-args; or exit 1
            end
        case screen
            grep -Fxq -- -o $tmp/grim-args; or exit 1
            grep -Fxq DP-2 $tmp/grim-args; or exit 1
    end
end
expect_files 3
set CAPTURE_CONTENT second
expect 0 screen
expect_files 4

for mode in cancel empty
    set PICKER_MODE $mode
    expect 1 area
    expect_files 4
end
set PICKER_MODE success
for mode in fail empty partial
    set CAPTURE_MODE $mode
    expect 1 screen
    expect_files 4
end
set CAPTURE_MODE success

# Saving succeeds even when clipboard access or notifications fail afterwards.
set CLIPBOARD_MODE fail
expect 1 screen
expect_files 5
set CLIPBOARD_MODE success
set NOTIFY_MODE fail
expect 0 screen
expect_files 6
set NOTIFY_MODE success

printf '%s\n' '{"dark":{"primary":null}}' >$HOME/.config/motif/spec/palette.json
expect 1 area
expect_files 6
expect 0 screen
expect_files 7
printf '%s\n' '{"dark":{"primary":"#12ab34"}}' >$HOME/.config/motif/spec/palette.json
for mode in error empty
    set QUERY_MODE $mode
    expect 1 screen
    expect 1 window
    expect_files 7
end
set QUERY_MODE success

# Selection must hold the lock too, not just the final capture.
set PICKER_MODE hold
$fish --no-config $script area >/dev/null 2>&1 &
set -l capture_pid $last_pid
for attempt in (seq 100)
    test -e $tmp/started; and break
    sleep 0.01
end
test -e $tmp/started; or exit 1
set PICKER_MODE success
expect 1 screen
wait $capture_pid; or exit 1
expect_files 8

# A persistent clipboard process must not retain the selection lock.
set CLIPBOARD_MODE child
expect 0 screen
set CLIPBOARD_MODE success
expect 0 screen
expect_files 10

set -l files $HOME/Pictures/Screenshots/*.png
for file in $files
    string match -qr '^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.png$' -- (path basename "$file"); or exit 1
    test (stat -c %a "$file") = 600; or exit 1
end

set -lx TEST_UUID (string replace -r '\.png$' '' -- (path basename "$files[1]"))
set -l original (string collect <"$files[1]")
rm $tmp/grim-args
printf '%s\n' '#!/bin/sh
if [ "$UUID_FAIL" = yes ]; then exit 1; fi
printf "%s\n" "$TEST_UUID"' >$tmp/bin/uuidgen
chmod +x $tmp/bin/uuidgen
expect 1 screen
test (string collect <"$files[1]") = "$original"; and test ! -e $tmp/grim-args; or exit 1
set -lx UUID_FAIL yes
expect 1 screen
test ! -e $tmp/grim-args; or exit 1
expect_files 10

printf 'PASS: capture targets, Motif picker colors, failure handling, UUIDv7 filenames, permissions, cancellation, clipboard preservation and locking\n'
