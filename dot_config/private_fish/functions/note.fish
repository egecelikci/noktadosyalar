function note --description 'Open a new timestamped note in ege.celikci.me'
    set -l repo ~/Git/ege.celikci.me
    pushd "$repo" >/dev/null; or return 1
    env NOTE_TITLE=(string join ' ' $argv) nvim -c NewNote
    popd >/dev/null
end
