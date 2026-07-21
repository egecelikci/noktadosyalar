function update-git-signers --description "Fetch public keys from Codeberg and update Git allowed_signers"
    echo "Fetching public keys from Codeberg…"
    mkdir -p ~/.config/git

    set -l keys (curl -sf https://codeberg.org/egecelikci.keys)
    if test $status -ne 0; or test -z "$keys"
        echo "Error: failed to fetch keys from Codeberg, leaving allowed_signers untouched." >&2
        return 1
    end

    printf '%s\n' "$keys" | sed 's/^/ege@celikci.me /' > ~/.config/git/allowed_signers
    echo "Successfully updated ~/.config/git/allowed_signers with latest keys."
end
