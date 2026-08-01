# Attach terminal OpenCode to the shared loopback server.
function oc --description 'Attach OpenCode to the shared Workbench server'
    set -l environment_file "$HOME/.config/opencode-workbench/server.env"
    if not test -r "$environment_file"
        printf 'oc: missing server environment: %s\n' "$environment_file" >&2
        printf 'Run `./dotfiles workbench install` from the dotfiles repository.\n' >&2
        return 1
    end

    for line in (string split \n -- (string collect <"$environment_file"))
        switch "$line"
            case 'OPENCODE_SERVER_USERNAME=*'
                set -lx OPENCODE_SERVER_USERNAME (string replace 'OPENCODE_SERVER_USERNAME=' '' -- "$line")
            case 'OPENCODE_SERVER_PASSWORD=*'
                set -lx OPENCODE_SERVER_PASSWORD (string replace 'OPENCODE_SERVER_PASSWORD=' '' -- "$line")
        end
    end

    if not set -q OPENCODE_SERVER_PASSWORD; or test -z "$OPENCODE_SERVER_PASSWORD"
        printf 'oc: OPENCODE_SERVER_PASSWORD is missing\n' >&2
        return 1
    end

    if command -q systemctl; and not systemctl --user is-active --quiet opencode-workbench.service
        systemctl --user start opencode-workbench.service
        or return
    end

    command opencode attach http://127.0.0.1:4096 --dir "$PWD" $argv
end
