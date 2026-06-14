function update-git-signers --description "Fetch public keys from Codeberg and update Git allowed_signers"
    echo "Fetching public keys from Codeberg..."
    
    mkdir -p ~/.config/git
    curl -s https://codeberg.org/egecelikci.keys | sed 's/^/ege@celikci.me /' > ~/.config/git/allowed_signers
    
    echo "Successfully updated ~/.config/git/allowed_signers with latest keys."
end
