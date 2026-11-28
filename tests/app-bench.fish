#!/usr/bin/env fish
# Run with `fish --no-config tests/app-bench.fish`; validates parsing, bundle matching, formatting, CSV export, and --fresh calibration using mocked macOS tools.

set -l script (path resolve (status dirname)/../dot_local/bin/executable_app-bench)
set -l ignore_file (path resolve (status dirname)/../.chezmoiignore)
set -l completions_file (path resolve (status dirname)/../dot_config/private_fish/completions/app-bench.fish)
set -l tmp (mktemp -d); or exit 1

function cleanup --on-event fish_exit --inherit-variable tmp --description 'Remove temporary test fixtures'
    rm -rf -- "$tmp"
end

function fail --argument-names msg --description 'Print test failure and exit non-zero'
    printf 'FAIL: %s\n' "$msg" >&2
    exit 1
end

mkdir -p "$tmp/bin" "$tmp/home/Applications/Vesktop.app" "$tmp/home/Library/Application Support/vesktop" "$tmp/home/Library/Application Support/Sunbird"; or exit 1

# Mock macOS system utilities so the script runs hermetically inside any environment.
printf '%s\n' \
    '#!/bin/sh' \
    'case "$2" in' \
    '  machdep.cpu.brand_string) echo "Apple M2 Pro" ;;' \
    '  hw.memsize) echo "17179869184" ;;' \
    'esac' >"$tmp/bin/sysctl"

printf '%s\n' '#!/bin/sh' 'echo "15.4"' >"$tmp/bin/sw_vers"

printf '%s\n' \
    '#!/bin/sh' \
    "cat >\"$tmp/clipboard.txt\"" >"$tmp/bin/pbcopy"

printf '%s\n' \
    '#!/bin/sh' \
    'for arg in "$@"; do' \
    '  case "$arg" in' \
    '    *Vesktop*|*vesktop*) printf "102400\t%s\n" "$arg" ;;' \
    '    *Sunbird*) printf "204800\t%s\n" "$arg" ;;' \
    '  esac' \
    'done' >"$tmp/bin/du"

printf '%s\n' \
    '#!/bin/sh' \
    "printf 'osascript %s\n' \"\$*\" >>\"$tmp/calib.log\"" \
    'case "$*" in' \
    "  *Vesktop*) touch \"$tmp/quit_Vesktop\" ;;" \
    "  *Sunbird*) touch \"$tmp/quit_Sunbird\" ;;" \
    'esac' >"$tmp/bin/osascript"

printf '%s\n' \
    '#!/bin/sh' \
    "printf 'open %s\n' \"\$*\" >>\"$tmp/calib.log\"" \
    "rm -f \"$tmp/quit_Vesktop\" \"$tmp/quit_Sunbird\"" >"$tmp/bin/open"

# Mock ps: includes Vesktop + helpers, Sunbird's patched Discord copy + helper, and an unrelated Discord Phoenix process that must NOT match Sunbird.
printf '%s\n' \
    '#!/bin/sh' \
    "if [ ! -f \"$tmp/quit_Vesktop\" ]; then" \
    '  cat <<EOF' \
    '  101 /Users/tester/Applications/Vesktop.app/Contents/MacOS/Vesktop --enable-features=UseOzonePlatform' \
    '  102 /Users/tester/Applications/Vesktop.app/Contents/Frameworks/Vesktop Helper (Renderer).app/Contents/MacOS/Vesktop Helper (Renderer) --type=renderer' \
    '  103 /Users/tester/Applications/Vesktop.app/Contents/Frameworks/Vesktop Helper (GPU).app/Contents/MacOS/Vesktop Helper (GPU) --type=gpu-process' \
    'EOF' \
    'fi' \
    "if [ ! -f \"$tmp/quit_Sunbird\" ]; then" \
    '  cat <<EOF' \
    '  201 /Users/tester/Library/Application Support/Sunbird/Sunbird.app/Contents/MacOS/Discord' \
    '  202 /Users/tester/Library/Application Support/Sunbird/Sunbird.app/Contents/Frameworks/Discord Helper (Renderer).app/Contents/MacOS/Discord Helper (Renderer) --type=renderer' \
    'EOF' \
    'fi' \
    'echo "  301 /Users/tester/Applications/Discord Phoenix.app/Contents/MacOS/Discord"' >"$tmp/bin/ps"

# Mock top: emits two blocks (first invalid 0.0% CPU block, second valid delta block) and increments metrics across calls so RAM delta and peaks are testable.
printf '%s\n' \
    '#!/bin/sh' \
    "n=0; [ -f \"$tmp/top_calls\" ] && n=\$(cat \"$tmp/top_calls\")" \
    'n=$((n + 1))' \
    "echo \"\$n\" >\"$tmp/top_calls\"" \
    'if [ "$n" -eq 1 ]; then' \
    '  v_mem="200M+"; v_gpu="102400K-"; s_mem="1.0G"; v_cpu="4.0"; s_cpu="2.0"; v_idw="20+"; s_idw="10"' \
    'else' \
    '  v_mem="250M"; v_gpu="102400K"; s_mem="1.0G"; v_cpu="12.0"; s_cpu="4.0"; v_idw="40"; s_idw="20"' \
    'fi' \
    'cat <<EOF' \
    'Processes: 400 total, 2 running, 398 sleeping' \
    'PID   %CPU  MEM     POWER  IDLEW  #TH' \
    '101+  0.0   100M    0.0    0      10' \
    '102   0.0   200M    0.0    0      20/1' \
    '103-  0.0   100M    0.0    0      8' \
    '201   0.0   120M    0.0    0      12' \
    '202   0.0   1.0G    0.0    0      18' \
    '301   0.0   999M    99.0   999    99' \
    '' \
    'Processes: 400 total, 2 running, 398 sleeping' \
    'PID   %CPU  MEM     POWER  IDLEW  #TH' \
    '101+  1.5   100M    1.0    5      10' \
    '102   $v_cpu $v_mem  3.5    $v_idw 20/1' \
    '103-  0.5   $v_gpu  0.5    5      8+' \
    '201   0.5   120M    0.5    5      12' \
    '202   $s_cpu $s_mem  2.5    $s_idw 18' \
    '301   50.0  999M    99.0   999    99' \
    'EOF' >"$tmp/bin/top"

chmod +x "$script" "$tmp"/bin/*; or exit 1

# Syntax-check both fish files and verify generated --help and --completions stay in sync.
fish --no-config -n "$script"; or fail 'app-bench has fish syntax errors'
fish --no-config -n "$completions_file"; or fail 'app-bench completions loader has fish syntax errors'
fish --no-config "$script" --help >"$tmp/help.txt"; or fail '--help failed'
grep -Fq -- '--duration <TIME>' "$tmp/help.txt"; or fail '--help missing generated --duration entry'
fish --no-config "$script" --completions >"$tmp/generated-completions.fish"; or fail '--completions failed'
fish --no-config -n "$tmp/generated-completions.fish"; or fail 'generated completions have fish syntax errors'
grep -Fq 'complete -c app-bench -s d -l duration' "$tmp/generated-completions.fish"; or fail 'generated completions missing --duration'
grep -Fq 'complete -c app-bench -s c -l csv -r -F' "$tmp/generated-completions.fish"; or fail 'generated completions missing file completion for --csv'

# Verify Darwin gating in .chezmoiignore.
grep -Fq '.local/bin/app-bench' "$ignore_file"; or fail 'missing .local/bin/app-bench in .chezmoiignore'
grep -Fq '.config/fish/completions/app-bench.fish' "$ignore_file"; or fail 'missing completions in .chezmoiignore'

set -lx PATH "$tmp/bin" $PATH
set -lx HOME "$tmp/home"

# 1. Snapshot mode: Markdown + processes + disk + note + clipboard.
fish --no-config "$script" --processes --disk --note "Same server, idle" Vesktop Sunbird >"$tmp/snap.md" 2>"$tmp/snap.err"; or fail 'snapshot mode failed'
grep -Fq '### App Benchmark · Snapshot (1s window)' "$tmp/snap.md"; or fail 'missing snapshot heading'
grep -Fq 'Apple M2 Pro · 16 GB RAM · macOS 15.4' "$tmp/snap.md"; or fail 'missing system info'
grep -Fq -- '- **Note:** Same server, idle' "$tmp/snap.md"; or fail 'missing note line'
# Vesktop: 100 + 200 + 100 = 400.0 MB, CPU 1.5+4.0+0.5 = 6.0%, Energy 1.0+3.5+0.5 = 5.0, Wakeups 5+20+5 = 30.0, 3 procs (38 threads), Disk 200 MB
grep -Fq '| Vesktop | 400.0 MB | 6.0% | 5.0 | 30.0 | 3 (38) | 200 MB |' "$tmp/snap.md"; or begin
    cat "$tmp/snap.md" >&2
    fail 'unexpected Vesktop snapshot row'
end
# Sunbird: 120 + 1024 = 1144.0 MB (must NOT include PID 301 Discord Phoenix 999M), CPU 2.5%, Energy 3.0, Wakeups 15.0, 2 procs (30 threads)
grep -Fq '| Sunbird | 1144.0 MB | 2.5% | 3.0 | 15.0 | 2 (30) |' "$tmp/snap.md"; or begin
    cat "$tmp/snap.md" >&2
    fail 'unexpected Sunbird snapshot row'
end
grep -Fq '| Sunbird | Discord Helper (Renderer) | 1024.0 MB | 2.0% | 2.5 | 18 |' "$tmp/snap.md"; or fail 'missing Sunbird helper in process breakdown'
test -s "$tmp/clipboard.txt"; or fail 'pbcopy was not called'
cmp -s "$tmp/snap.md" "$tmp/clipboard.txt"; or fail 'clipboard contents differ from stdout'

# 2. Benchmark mode: 2 samples × 2s, Discord format + CSV + --no-copy.
rm -f "$tmp/top_calls" "$tmp/clipboard.txt"
fish --no-config "$script" -d 4s -i 2 --discord --csv "$tmp/bench.csv" --no-copy Vesktop Sunbird >"$tmp/bench.discord" 2>"$tmp/bench.err"; or fail 'benchmark mode failed'
test ! -e "$tmp/clipboard.txt"; or fail '--no-copy should not invoke pbcopy'
grep -Fq '**App Benchmark** · 4s (2 × 2s) · Apple M2 Pro · 16 GB RAM · macOS 15.4' "$tmp/bench.discord"; or fail 'missing Discord header'
grep -Fq '```text' "$tmp/bench.discord"; or fail 'missing Discord code block'
# Vesktop: sample1=400 MB / 6% CPU, sample2=450 MB / 14% CPU => Avg 425.0 MB, Peak 450.0 MB, Delta +50.0 MB, CPU 10.0% / 14.0%, CPU Time 0.4s
grep -Fq '425.0 MB' "$tmp/bench.discord"; or begin
    cat "$tmp/bench.discord" >&2
    fail 'unexpected Vesktop benchmark RAM average'
end
grep -Fq '+50.0 MB' "$tmp/bench.discord"; or fail 'unexpected Vesktop RAM delta'
grep -Fq '10.0% / 14.0%' "$tmp/bench.discord"; or fail 'unexpected Vesktop CPU avg/peak'
test (wc -l <"$tmp/bench.csv" | string trim) -eq 5; or fail 'expected header + 4 CSV rows (2 samples × 2 apps)'

# 3. Calibration mode (--fresh --warmup 0) + --format both.
rm -f "$tmp/top_calls" "$tmp/calib.log"
fish --no-config "$script" --fresh --warmup 0 --format both --no-copy Vesktop Sunbird >"$tmp/both.txt" 2>"$tmp/both.err"; or fail '--fresh mode failed'
grep -Fq -- '-- Vesktop' "$tmp/calib.log"; or fail '--fresh did not quit Vesktop'
grep -Fq -- '-- Sunbird' "$tmp/calib.log"; or fail '--fresh did not quit Sunbird'
grep -Fq 'open -a' "$tmp/calib.log"; or fail '--fresh did not relaunch apps'
grep -Fq 'fresh launch' "$tmp/both.txt"; or fail 'missing fresh launch tag in report'
grep -Fq '### App Benchmark' "$tmp/both.txt"; or fail 'missing markdown section in --format both'
grep -Fq '```text' "$tmp/both.txt"; or fail 'missing discord section in --format both'
grep -Fq '| --- | --- | ---: |' "$tmp/snap.md"; or fail 'processes table should left-align both App and Process columns'

printf 'PASS: app-bench snapshot, benchmark, Discord/Markdown formatting, CSV, --fresh calibration, and Darwin chezmoi gating\n'
