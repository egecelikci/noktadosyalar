#!/usr/bin/env fish

set -l settings "$HOME/.pi/agent/settings.json"
set -l manifest "$HOME/.pi/agent/npm/package.json"

if test -f "$manifest"
    exit 0
end

if not type -q pi
    echo "pi not on PATH; nothing to bootstrap yet" >&2
    exit 0
end

if not test -f "$settings"
    echo "no $settings; nothing to bootstrap" >&2
    exit 0
end

set -l declared (
    string match -r '"npm:[^"]+"' <"$settings" \
        | string replace -ra '^"npm:' '' \
        | string replace -r '"$' ''
)

for pkg in $declared
    echo "→ pi install npm:$pkg"
    if not pi install "npm:$pkg" </dev/null
        echo "warn: pi install npm:$pkg failed" >&2
    end
end
