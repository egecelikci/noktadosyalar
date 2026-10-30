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
    'set $lock $ipc session lock || swaylock -f -c 000000' \
    'bindsym --no-repeat $mod+space exec $ipc panel-toggle launcher' \
    'bindsym --no-repeat $mod+Ctrl+v exec $ipc panel-toggle clipboard' \
    'bindsym --no-repeat $mod+n exec $ipc panel-toggle control-center notifications' \
    'bindsym --no-repeat $mod+m exec $ipc panel-toggle control-center audio' \
    'bindsym --locked XF86AudioRaiseVolume exec $ipc volume-up' \
    'bindsym --locked XF86AudioLowerVolume exec $ipc volume-down' \
    'bindsym $mod+Ctrl+q exec $lock' \
    'include ~/.config/sway/noctalia' \
    '  bindsym --no-repeat w exec $ipc screenshot-window, mode "default"' \
    '  bindsym --no-repeat a exec $ipc screenshot-fullscreen, mode "default"' \
    '  bindsym --no-repeat d exec $ipc screenshot-region, mode "default"'
    if not grep -Fxq -- "$binding" "$config"
        printf 'FAIL: missing binding: %s\n' "$binding" >&2
        exit 1
    end
end

if grep -Eq '^[[:space:]]*(exec(_always)?[[:space:]].*(mako|wob|waybar|swayidle|noctalia)|swaybar_command|output.*[[:space:]]bg[[:space:]]|client\.)|makoctl|wob\.fifo|motif|\$shot|\.local/bin/screenshot' "$config"
    printf 'FAIL: competing shell, theme or screenshot configuration\n' >&2
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

set -l package (path dirname (path dirname (path resolve (command -s noctalia))))
set -l template $package/share/noctalia/assets/templates/sway/sway
jq -n '{dark:{primary:"#123456",on_primary:"#ffffff",secondary:"#234567",tertiary:"#345678",error:"#ff0000",surface:"#101010",on_surface:"#eeeeee",on_surface_variant:"#aaaaaa",outline:"#777777"},light:{primary:"#abcdef",on_primary:"#000000",secondary:"#bcdef0",tertiary:"#cdef01",error:"#cc0000",surface:"#fafafa",on_surface:"#111111",on_surface_variant:"#444444",outline:"#888888"}}' >$tmp/palette.json; or exit 1
for mode in dark light
    noctalia theme --theme-json $tmp/palette.json --default-mode $mode --render "$template:$tmp/sway-theme" >$tmp/render.log 2>&1; or begin
        string collect <$tmp/render.log >&2
        exit 1
    end
    set -l primary 123456
    test $mode = light; and set primary abcdef
    grep -Eq '^set \$primary[[:space:]]+#'$primary'[[:space:]]*$' $tmp/sway-theme; or exit 1
end
printf '%s\n' '[templates.sway]' "input_path = \"$template\"" "output_path = \"$tmp/hook-theme\"" "post_hook = \"test -s '$tmp/hook-theme' && touch '$tmp/hook-called'\"" >$tmp/template-hook.toml
noctalia theme --theme-json $tmp/palette.json --config $tmp/template-hook.toml >$tmp/hook.log 2>&1; or begin
    string collect <$tmp/hook.log >&2
    exit 1
end
test -f $tmp/hook-called; or exit 1

set -l foot_template $package/share/noctalia/assets/templates/foot/foot
set -l terminal_keys (string match --all --regex --groups-only '\{\{colors\.([a-z_]+)\.default\.hex_stripped\}\}' <$foot_template)
jq --args 'reduce $ARGS.positional[] as $key (. ; .dark[$key] = "#123456" | .light[$key] = "#abcdef")' $terminal_keys <$tmp/palette.json >$tmp/foot-palette.json; or exit 1
for mode in dark light
    noctalia theme --theme-json $tmp/foot-palette.json --default-mode $mode --render "$foot_template:$tmp/foot.ini" >$tmp/foot-render.log 2>&1; or begin
        string collect <$tmp/foot-render.log >&2
        exit 1
    end
    foot --check-config --config $tmp/foot.ini >$tmp/foot-check.log 2>&1; or begin
        string collect <$tmp/foot-check.log >&2
        exit 1
    end
end

# Validate the real config against generated colours without changing the live theme or touching the display.
string replace -- 'include ~/.config/sway/noctalia' "include $tmp/sway-theme" <"$config" >$tmp/sway-config

env WLR_BACKENDS=headless WLR_RENDERER=pixman sway --validate --config $tmp/sway-config >$tmp/sway.log 2>&1
if test $status -ne 0
    string collect <$tmp/sway.log >&2
    exit 1
end
printf 'PASS: Sway syntax, native screenshots, generated Sway/Foot themes, lock fallback and single shell owner\n'
