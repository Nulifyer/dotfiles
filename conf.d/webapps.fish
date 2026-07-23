# Native Fish helpers for creating and removing browser-backed desktop apps.
#
# Commands:
#   webapp
#   webapp install [--force] [NAME URL [ICON]]
#   webapp remove [NAME_OR_ID ...]
#   webapp list
#   webapp-install / webapp-remove / webapp-list
#   omarchy-webapp-install / omarchy-webapp-remove
#
# Set WEBAPP_BROWSER to override the browser executable. It must support
# Chromium's --app=URL option.

function __webapp_help
    printf '%s\n' \
        'Manage browser-backed desktop apps.' \
        '' \
        'Usage:' \
        '  webapp                         Open the interactive action menu' \
        '  webapp install [--force] [NAME URL [ICON]]' \
        '  webapp remove [NAME_OR_ID ...]' \
        '  webapp list' \
        '' \
        'ICON may be a local image path or an HTTP(S) URL.' \
        'Set WEBAPP_BROWSER to override the detected Chromium-based browser.'
end

function __webapp_data_home
    if set -q XDG_DATA_HOME; and test -n "$XDG_DATA_HOME"
        printf '%s\n' "$XDG_DATA_HOME"
    else
        printf '%s\n' "$HOME/.local/share"
    end
end

function __webapp_browser
    if set -q WEBAPP_BROWSER; and test -n "$WEBAPP_BROWSER"
        if string match -rq '[[:space:]"]' -- "$WEBAPP_BROWSER"
            printf 'webapp: WEBAPP_BROWSER must be an executable without arguments\n' >&2
            return 1
        end

        if command -q -- "$WEBAPP_BROWSER"; or test -x "$WEBAPP_BROWSER"
            printf '%s\n' "$WEBAPP_BROWSER"
            return
        end

        printf 'webapp: browser not found: %s\n' "$WEBAPP_BROWSER" >&2
        return 1
    end

    for browser in brave chromium chromium-browser google-chrome-stable google-chrome vivaldi
        if command -q -- $browser
            printf '%s\n' $browser
            return
        end
    end

    printf '%s\n' \
        'webapp: no supported Chromium-based browser found.' \
        'Install one or set WEBAPP_BROWSER to its executable.' >&2
    return 1
end

function __webapp_id --argument-names name
    string lower -- "$name" |
        string replace -ar '[^a-z0-9._-]+' - |
        string trim --chars='-.'
end

function __webapp_records
    set -l applications_dir (__webapp_data_home)/applications
    test -d "$applications_dir"; or return

    for desktop_file in "$applications_dir"/*.desktop
        test -f "$desktop_file"; or continue
        command grep -qx 'X-Fish-WebApp=true' "$desktop_file"; or continue

        set -l id (path basename "$desktop_file" | string replace -r '\.desktop$' '')
        set -l name (string match -r '^Name=.*' <"$desktop_file" | string replace -r '^Name=' '')
        set -l url (string match -r '^X-WebApp-URL=.*' <"$desktop_file" | string replace -r '^X-WebApp-URL=' '')
        printf '%s\t%s\t%s\n' "$id" "$name" "$url"
    end
end

function __webapp_install
    argparse f/force -- $argv
    or return

    set -l name
    set -l url
    set -l icon_ref

    switch (count $argv)
        case 0
            read --prompt-str='Name> ' name
            or return 1
            read --prompt-str='URL> ' url
            or return 1
            read --prompt-str='Icon path or URL (optional)> ' icon_ref
        case 2 3
            set name "$argv[1]"
            set url "$argv[2]"
            if test (count $argv) -eq 3
                set icon_ref "$argv[3]"
            end
        case '*'
            printf 'Usage: webapp install [--force] [NAME URL [ICON]]\n' >&2
            return 2
    end

    set name (string replace -ar '[\r\n\t]+' ' ' -- "$name" | string trim)
    set url (string trim -- "$url")
    set icon_ref (string trim -- "$icon_ref")

    if test -z "$name"; or test -z "$url"
        printf 'webapp: both name and URL are required\n' >&2
        return 1
    end

    if not string match -rq '^[a-zA-Z][a-zA-Z0-9+.-]*://' -- "$url"
        set url "https://$url"
    end

    if not string match -rq '^https?://[^[:space:]"]+$' -- "$url"; or string match -rq '\\\\' -- "$url"
        printf 'webapp: URL must be a valid HTTP(S) URL without spaces\n' >&2
        return 1
    end

    set -l id (__webapp_id "$name")
    if test -z "$id"
        printf 'webapp: the name must contain at least one letter or number\n' >&2
        return 1
    end

    set -l browser (__webapp_browser)
    or return

    set -l data_home (__webapp_data_home)
    set -l applications_dir "$data_home/applications"
    set -l icons_dir "$applications_dir/icons"
    set -l desktop_file "$applications_dir/$id.desktop"
    command mkdir -p "$icons_dir"
    or return

    if test -e "$desktop_file"; and not set -q _flag_force
        printf 'webapp: %s already exists; use --force to replace it\n' "$id" >&2
        return 1
    end

    set -l icon_value applications-internet
    if test -n "$icon_ref"
        if string match -rq '^https?://' -- "$icon_ref"
            set -l icon_file "$icons_dir/$id.png"
            if command curl --fail --silent --show-error --location \
                    --output "$icon_file" "$icon_ref"
                set icon_value "$icon_file"
            else
                command rm -f -- "$icon_file"
                printf 'webapp: icon download failed; using the generic web icon\n' >&2
            end
        else if test -f "$icon_ref"
            set -l extension (path extension "$icon_ref")
            test -n "$extension"; or set extension .img
            set -l icon_file "$icons_dir/$id$extension"
            command cp -- "$icon_ref" "$icon_file"
            or return
            set icon_value "$icon_file"
        else
            printf 'webapp: icon file not found: %s\n' "$icon_ref" >&2
            return 1
        end
    else
        set -l icon_file "$icons_dir/$id.png"
        set -l favicon_url "https://www.google.com/s2/favicons?domain=$url&sz=128"
        if command curl --fail --silent --location --output "$icon_file" "$favicon_url"
            set icon_value "$icon_file"
        else
            command rm -f -- "$icon_file"
        end
    end

    # A percent sign in a Desktop Entry Exec value must be doubled so it is
    # not interpreted as a field code.
    set -l exec_url (string replace -a '%' '%%' -- "$url")

    printf '%s\n' \
        '[Desktop Entry]' \
        'Version=1.0' \
        'Type=Application' \
        "Name=$name" \
        "Comment=Web app for $url" \
        "Exec=$browser --app=$exec_url" \
        "Icon=$icon_value" \
        'Terminal=false' \
        'Categories=Network;' \
        'StartupNotify=true' \
        "X-WebApp-URL=$url" \
        'X-Fish-WebApp=true' >"$desktop_file"
    or return

    command chmod +x "$desktop_file"
    command -q update-desktop-database
    and command update-desktop-database "$applications_dir" >/dev/null 2>&1

    printf 'Installed %s (%s)\n' "$name" "$id"
end

function __webapp_list
    set -l records (__webapp_records)
    if test (count $records) -eq 0
        printf 'No Fish-managed web apps installed.\n'
        return
    end

    printf '%-24s  %-28s  %s\n' ID NAME URL
    for record in $records
        set -l fields (string split \t -- "$record")
        printf '%-24s  %-28s  %s\n' "$fields[1]" "$fields[2]" "$fields[3]"
    end
end

function __webapp_remove
    set -l records (__webapp_records)
    if test (count $records) -eq 0
        printf 'No Fish-managed web apps installed.\n'
        return
    end

    set -l ids
    if test (count $argv) -eq 0
        if not command -q fzf
            printf 'webapp: fzf is required for interactive removal\n' >&2
            return 1
        end

        set -l selected (printf '%s\n' $records |
            fzf --multi --delimiter=\t --with-nth=2,3 \
                --prompt='Remove web apps> ' \
                --header='Tab: select multiple · Enter: remove')
        or return

        for record in $selected
            set -a ids (string split \t -- "$record")[1]
        end
    else
        set -l missing
        for requested in $argv
            set -l matched false
            for record in $records
                set -l fields (string split \t -- "$record")
                if test "$requested" = "$fields[1]"; or test "$requested" = "$fields[2]"
                    set -a ids "$fields[1]"
                    set matched true
                    break
                end
            end
            if test "$matched" = false
                set -a missing "$requested"
            end
        end

        if test (count $missing) -gt 0
            printf 'webapp: not found: %s\n' (string join ', ' -- $missing) >&2
            return 1
        end
    end

    test (count $ids) -gt 0; or return

    set -l applications_dir (__webapp_data_home)/applications
    set -l icons_dir "$applications_dir/icons"
    for id in $ids
        set -l desktop_file "$applications_dir/$id.desktop"
        set -l icon_value
        if test -f "$desktop_file"
            set icon_value (string match -r '^Icon=.*' <"$desktop_file" | string replace -r '^Icon=' '')
        end

        command rm -f -- "$desktop_file"
        if test -n "$icon_value"; and string match -q "$icons_dir/*" -- "$icon_value"
            command rm -f -- "$icon_value"
        end
        printf 'Removed %s\n' "$id"
    end

    command -q update-desktop-database
    and command update-desktop-database "$applications_dir" >/dev/null 2>&1
end

function webapp --description 'Manage browser-backed desktop apps'
    if test (count $argv) -eq 0
        if not command -q fzf
            __webapp_help
            return
        end

        set -l action (printf '%s\n' install remove list |
            fzf --prompt='Web apps> ' --header='Choose an action')
        or return
        set argv $action
    end

    set -l action $argv[1]
    set -e argv[1]
    switch $action
        case install add
            __webapp_install $argv
        case remove rm delete
            __webapp_remove $argv
        case list ls
            __webapp_list
        case help -h --help
            __webapp_help
        case '*'
            printf 'webapp: unknown action: %s\n\n' "$action" >&2
            __webapp_help >&2
            return 2
    end
end

function webapp-install --description 'Create a browser-backed desktop app'
    webapp install $argv
end

function webapp-remove --description 'Remove browser-backed desktop apps'
    webapp remove $argv
end

function webapp-list --description 'List browser-backed desktop apps'
    webapp list $argv
end

# Native Fish replacements for Omarchy's legacy command names.
function omarchy-webapp-install --description 'Create a browser-backed desktop app'
    webapp install $argv
end

function omarchy-webapp-remove --description 'Remove browser-backed desktop apps'
    webapp remove $argv
end

complete --command webapp --no-files
complete --command webapp --condition __fish_use_subcommand \
    --arguments install --description 'Create a web app'
complete --command webapp --condition __fish_use_subcommand \
    --arguments remove --description 'Remove web apps'
complete --command webapp --condition __fish_use_subcommand \
    --arguments list --description 'List web apps'
complete --command webapp --condition '__fish_seen_subcommand_from install add' \
    --short-option f --long-option force --description 'Replace an existing launcher'
complete --command webapp-install --short-option f --long-option force \
    --description 'Replace an existing launcher'
complete --command omarchy-webapp-install --short-option f --long-option force \
    --description 'Replace an existing launcher'
