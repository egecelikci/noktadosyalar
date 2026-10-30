#!/usr/bin/env fish
# Run with `fish --no-config tests/noctalia.fish`; validates config and IPC names without sending commands to the desktop.

set -l config (path resolve (status dirname)/../dot_config/sway/config)
set -l tmp (mktemp -d); or exit 1
mkdir -m 700 $tmp/runtime; or exit 1
set -lx XDG_RUNTIME_DIR $tmp/runtime

function cleanup --on-event fish_exit --inherit-variable tmp --description 'Remove the isolated validation output'
    rm -rf -- "$tmp"
end

for binding in \
    'set $ipc noctalia msg' \
    'set $lock $ipc session lock || swaylock -f -c $motif_bg_bare' \
    'bindsym --no-repeat $mod+space exec $ipc panel-toggle launcher' \
    'bindsym --no-repeat $mod+Ctrl+v exec $ipc panel-toggle clipboard' \
    'bindsym --no-repeat $mod+n exec $ipc panel-toggle control-center notifications' \
    'bindsym --no-repeat $mod+m exec $ipc panel-toggle control-center audio' \
    'bindsym --locked XF86AudioRaiseVolume exec $ipc volume-up' \
    'bindsym --locked XF86AudioLowerVolume exec $ipc volume-down' \
    'bindsym $mod+Ctrl+q exec $lock'
    if not grep -Fxq -- "$binding" "$config"
        printf 'FAIL: missing binding: %s\n' "$binding" >&2
        exit 1
    end
end

if grep -Eq '^[[:space:]]*(exec(_always)?[[:space:]].*(mako|wob|waybar|swayidle|noctalia)|swaybar_command|output.*[[:space:]]bg[[:space:]])|makoctl|wob\.fifo' "$config"
    printf 'FAIL: competing shell autostart, wallpaper or notification command\n' >&2
    exit 1
end

noctalia msg --help >$tmp/ipc-help; or exit 1
set -l commands session (string match --regex --groups-only 'exec \$ipc ([a-z-]+)' <"$config")
for command in $commands
    if not grep -Eq "^[[:space:]]+$command([[:space:]]|\$)" $tmp/ipc-help
        printf 'FAIL: IPC command is not supported by this Noctalia version: %s\n' "$command" >&2
        exit 1
    end
end

env WLR_BACKENDS=headless WLR_RENDERER=pixman sway --validate --config "$config" >$tmp/sway.log 2>&1
if test $status -ne 0
    string collect <$tmp/sway.log >&2
    exit 1
end
printf 'PASS: Sway syntax, Noctalia bindings, lock fallback and single shell owner\n'
