# Interactive Wallhaven browser with terminal image previews.
#
# Dependencies: curl, jq, fzf, and either Kitty's `kitten` or chafa.
# Optional environment:
#   WALLHAVEN_API_KEY       Enables account filters and NSFW results
#   WALLHAVEN_RESOLUTION    Overrides automatic display resolution detection
#   WALLHAVEN_DOWNLOAD_DIR  Overrides ~/Pictures/wallpaper

function __wallhaven_help
    printf '%s\n' \
        'Browse wallhaven.cc with image previews.' \
        '' \
        'Usage:' \
        '  wallhaven [OPTIONS] [QUERY]' \
        '' \
        'Options:' \
        '  -q, --query TEXT          Search terms (remaining arguments also work)' \
        '  -r, --resolution WxH      Minimum resolution (default: auto-detected)' \
        '      --ratio WxH           Aspect ratio (default: auto-detected)' \
        '      --no-resolution       Do not filter by resolution' \
        '  -s, --sorting MODE        latest, relevance, random, views, favorites,' \
        '                            or toplist (default: latest)' \
        '  -o, --order ORDER         desc or asc (default: desc)' \
        '  -p, --page NUMBER         Start on this results page (default: 1)' \
        '      --purity FILTER       sfw, sketchy, nsfw, comma lists, or API bits' \
        '      --categories FILTER   general, anime, people, comma lists, or bits' \
        '      --top-range RANGE     1d, 3d, 1w, 1M, 3M, 6M, or 1y' \
        '  -h, --help                Show this help' \
        '' \
        'Keys:' \
        '  Enter   Submit a Wallhaven search' \
        '  Ctrl-O  Open the wallpaper page' \
        '  Ctrl-D  Save the original to ~/Pictures/wallpaper' \
        '  Ctrl-P  Toggle the image preview' \
        '  Ctrl-R  Relax size and ratio filters' \
        '  F2      Edit API filters' \
        '  Alt-→   Load more results' \
        '  Esc     Quit' \
        '' \
        'NSFW results require WALLHAVEN_API_KEY.'
end

function __wallhaven_cache_home
    if set -q XDG_CACHE_HOME; and test -n "$XDG_CACHE_HOME"
        printf '%s\n' "$XDG_CACHE_HOME/fish-wallhaven"
    else
        printf '%s\n' "$HOME/.cache/fish-wallhaven"
    end
end

function __wallhaven_clear_temporary_directory --argument-names directory
    for temporary_file in "$directory"/*
        command rm -f -- "$temporary_file"
    end
end

function __wallhaven_has_api_key
    set -q WALLHAVEN_API_KEY
    and test -n "$WALLHAVEN_API_KEY"
end

function __wallhaven_download_dir
    if set -q WALLHAVEN_DOWNLOAD_DIR; and test -n "$WALLHAVEN_DOWNLOAD_DIR"
        printf '%s\n' "$WALLHAVEN_DOWNLOAD_DIR"
    else
        printf '%s\n' "$HOME/Pictures/wallpaper"
    end
end

function __wallhaven_emit_results --argument-names rows
    printf '  %-14s%-18s%5s\n' RESOLUTION CATEGORY FAVS

    while read -l row
        set -l fields (string split \t -- "$row")
        if test (count $fields) -lt 13
            continue
        end

        set -l marker '  '
        set -l destination (__wallhaven_download_dir)/(path basename "$fields[13]")
        if test -s "$destination"
            set marker \e'[32m✓ '\e'[0m'
        end

        set -l category "$fields[6]"
        if test "$fields[7]" != sfw
            set category "$category/$fields[7]"
        end

        set -l visible (printf '%b%-14s%-18s%5s' \
            "$marker" "$fields[3]" "$category" "$fields[5]")
        printf '%s\t%s\n' "$visible" (string join \t -- $fields[2..-1])
    end <"$rows"
end

function __wallhaven_fetch_page \
    --argument-names response rows page query categories purity sorting order resolution ratio top_range random_seed
    set -l curl_args \
        --fail --silent --show-error --location --get \
        --max-time 30 \
        --output "$response" \
        --data-urlencode "q=$query" \
        --data "categories=$categories" \
        --data "purity=$purity" \
        --data "sorting=$sorting" \
        --data "order=$order" \
        --data "page=$page"

    if test -n "$resolution"
        set -a curl_args --data "atleast=$resolution"
    end
    if test -n "$ratio"
        set -a curl_args --data "ratios=$ratio"
    end
    if test "$sorting" = toplist
        set -a curl_args --data "topRange=$top_range"
    end
    if test -n "$random_seed"
        set -a curl_args --data "seed=$random_seed"
    end
    if set -q WALLHAVEN_API_KEY; and test -n "$WALLHAVEN_API_KEY"
        set -a curl_args --data-urlencode "apikey=$WALLHAVEN_API_KEY"
    end

    command curl $curl_args https://wallhaven.cc/api/v1/search
    or return 1

    if not command jq -e '.data | type == "array"' "$response" >/dev/null
        command jq -r '.error // "invalid API response"' "$response" >&2
        return 1
    end

    command jq -r '
        def rpad($width):
            tostring as $text
            | $text + (" " * ([0, $width - ($text | length)] | max));
        def lpad($width):
            tostring as $text
            | (" " * ([0, $width - ($text | length)] | max)) + $text;

        .data[]
        | [
            (
                (.id | rpad(8))
                + (.resolution | rpad(14))
                + ((.category + "/" + .purity) | rpad(18))
                + (.favorites | lpad(5))
            ),
            .id,
            .resolution,
            (.category + "/" + .purity),
            (.favorites | tostring),
            .category,
            .purity,
            ((.file_size / 1048576 * 10 | round) / 10 | tostring) + " MiB",
            (.views | tostring),
            .created_at[0:10],
            .thumbs.large,
            .url,
            .path
          ]
        | @tsv
    ' "$response" >>"$rows"
end

function __wallhaven_filter_summary \
    --argument-names resolution_mode auto_resolution ratio auto_ratio \
    sorting order categories_filter purity_filter top_range
    set -l resolution_status
    switch "$resolution_mode"
        case auto
            set resolution_status "auto≥"(string replace x '×' -- "$auto_resolution")
        case any
            set resolution_status 'any size'
        case '*'
            set resolution_status "≥"(string replace x '×' -- "$resolution_mode")
    end

    set -l ratio_status
    switch "$ratio"
        case auto
            set ratio_status "auto "(string replace x ':' -- "$auto_ratio")
        case any
            set ratio_status 'any ratio'
        case '*'
            set ratio_status (string replace x ':' -- "$ratio")
    end

    set -l sorting_status (string lower -- \
        (__wallhaven_filter_label sorting "$sorting"))
    set -l order_arrow '↓'
    if test "$order" = asc
        set order_arrow '↑'
    end

    set -l categories_status "$categories_filter"
    switch "$categories_filter"
        case general,anime,people 111
            set categories_status all
        case general,anime
            set categories_status 'general+anime'
        case '*'
            set categories_status (string replace -a , + -- "$categories_filter")
    end
    set -l purity_status (string upper -- \
        (string replace -a , + -- "$purity_filter"))

    set -l summary \
        "$resolution_status · $ratio_status · $sorting_status$order_arrow · $categories_status · $purity_status"
    if test "$sorting" = toplist
        set summary "$summary · $top_range"
    end
    printf '%s\n' "$summary"
end

function __wallhaven_state_input_label --argument-names state
    set -l query (command jq -r '.query // ""' "$state")
    set -l summary (__wallhaven_filter_summary \
        (command jq -r '
            .resolution_mode,
            .auto_resolution,
            .ratio_mode,
            .auto_ratio,
            .sorting,
            .order,
            .categories_filter,
            .purity_filter,
            .top_range
        ' "$state"))

    if test -n "$query"
        set -l query_status (string sub --length 24 -- "$query")
        if test (string length -- "$query") -gt 24
            set query_status "$query_status…"
        end
        set summary "“$query_status” · $summary"
    end
    printf ' %s ' "$summary"
end

function __wallhaven_state_border_label --argument-names state
    set -l notice (command jq -r '.notice // ""' "$state")
    if test -n "$notice"
        if string match -q 'No results*' -- "$notice"
            printf ' No results · ^R Relax · ↵ Search · F2 Filters · Esc Quit '
        else
            printf ' %s · ↵ Search · F2 Filters · Esc Quit ' "$notice"
        end
        return
    end

    set -l current (command jq -r '.current' "$state")
    set -l last (command jq -r '.last' "$state")
    set -l more
    if test "$current" -lt "$last"
        set more ' · ⎇→ More'
    end
    printf ' ↵ Search · ^O Open · ^D Save · F2 Filters%s · Esc Quit ' "$more"
end

function __wallhaven_clear_temporary_notice --argument-names state
    if test (command jq -r '.notice_temporary // false' "$state") = true
        sleep 2
        if test (command jq -r '.notice_temporary // false' "$state") = true
            set -l updated_state (command mktemp "$state.XXXXXX")
            command jq '.notice = "" | .notice_temporary = false' \
                "$state" >"$updated_state"
            and command mv -- "$updated_state" "$state"
        end
    end
    __wallhaven_state_border_label "$state"
end

function __wallhaven_after_load --argument-names state
    if test (command jq -r '.focus_first // false' "$state") != true
        return
    end

    set -l updated_state (command mktemp "$state.XXXXXX")
    command jq '.focus_first = false' "$state" >"$updated_state"
    and command mv -- "$updated_state" "$state"
    printf 'first\n'
end

function __wallhaven_load_more --argument-names state rows temporary_dir
    set -l current (command jq -r '.current' "$state")
    set -l last (command jq -r '.last' "$state")
    if test "$current" -ge "$last"
        __wallhaven_emit_results "$rows"
        return
    end

    set -l page (math "$current + 1")
    set -l response "$temporary_dir/page-$page.json"
    set -l query (command jq -r '.query' "$state")
    set -l categories (command jq -r '.categories' "$state")
    set -l purity (command jq -r '.purity' "$state")
    set -l sorting (command jq -r '.sorting' "$state")
    set -l order (command jq -r '.order' "$state")
    set -l resolution (command jq -r '.resolution' "$state")
    set -l ratio (command jq -r '.ratio' "$state")
    set -l top_range (command jq -r '.top_range' "$state")
    set -l random_seed (command jq -r '.random_seed' "$state")

    if not __wallhaven_fetch_page \
            "$response" "$rows" "$page" "$query" "$categories" "$purity" \
            "$sorting" "$order" "$resolution" "$ratio" "$top_range" "$random_seed"
        set -l failed_state (command mktemp "$state.XXXXXX")
        command jq '
            .notice = "Could not load more — previous results kept"
            | .notice_temporary = false
        ' \
            "$state" >"$failed_state"
        and command mv -- "$failed_state" "$state"
        __wallhaven_emit_results "$rows"
        return
    end

    set current (command jq -r '.meta.current_page // 1' "$response")
    set last (command jq -r '.meta.last_page // 1' "$response")
    if test "$sorting" = random; and test -z "$random_seed"
        set random_seed (command jq -r '.meta.seed // empty' "$response")
    end

    set -l updated_state (command mktemp "$state.XXXXXX")
    command jq \
        --argjson current "$current" \
        --argjson last "$last" \
        --arg random_seed "$random_seed" \
        '.current = $current
            | .last = $last
            | .random_seed = $random_seed
            | .notice = ""
            | .notice_temporary = false' \
        "$state" >"$updated_state"
    and command mv -- "$updated_state" "$state"

    __wallhaven_emit_results "$rows"
end

function __wallhaven_restore_previous_filters --argument-names state notice
    set -l updated_state (command mktemp "$state.XXXXXX")
    command jq --arg notice "$notice" '
        if (.previous_filters // null) != null then
            .resolution_mode = .previous_filters.resolution_mode
            | .ratio_mode = .previous_filters.ratio_mode
            | .sorting = .previous_filters.sorting
            | .order = .previous_filters.order
            | .categories_filter = .previous_filters.categories_filter
            | .purity_filter = .previous_filters.purity_filter
            | .top_range = .previous_filters.top_range
        else
            .
        end
        | .pending_filters = false
        | .notice = $notice
        | .notice_temporary = false
        | .focus_first = false
        | del(.previous_filters)
    ' "$state" >"$updated_state"
    and command mv -- "$updated_state" "$state"
end

function __wallhaven_refresh_results --argument-names state rows temporary_dir requested_query
    set -l resolution_mode (command jq -r '.resolution_mode' "$state")
    set -l auto_resolution (command jq -r '.auto_resolution' "$state")
    set -l ratio_mode (command jq -r '.ratio_mode' "$state")
    set -l auto_ratio (command jq -r '.auto_ratio' "$state")
    set -l sorting (command jq -r '.sorting' "$state")
    set -l order (command jq -r '.order' "$state")
    set -l categories_filter (command jq -r '.categories_filter' "$state")
    set -l purity_filter (command jq -r '.purity_filter' "$state")
    set -l top_range (command jq -r '.top_range' "$state")

    set -l resolution
    switch "$resolution_mode"
        case auto
            set resolution "$auto_resolution"
        case any
            set resolution
        case '*'
            set resolution "$resolution_mode"
    end

    set -l ratio
    switch "$ratio_mode"
        case auto
            set ratio "$auto_ratio"
        case any
            set ratio
        case '*'
            set ratio "$ratio_mode"
    end

    set -l categories (__wallhaven_filter_bits categories "$categories_filter")
    or begin
        __wallhaven_restore_previous_filters "$state" 'Invalid category filters'
        __wallhaven_emit_results "$rows"
        return
    end
    set -l purity (__wallhaven_filter_bits purity "$purity_filter")
    or begin
        __wallhaven_restore_previous_filters "$state" 'Invalid purity filters'
        __wallhaven_emit_results "$rows"
        return
    end

    set -l new_rows (command mktemp "$temporary_dir/results.XXXXXX")
    set -l random_seed
    set -l current_page (command jq -r '.requested_start // 1' "$state")
    set -l first_page "$current_page"
    set -l last_page 1
    set -l response

    for load_index in 1 2
        set response "$temporary_dir/refresh-$fish_pid-page-$current_page.json"
        if not __wallhaven_fetch_page \
                "$response" "$new_rows" "$current_page" "$requested_query" \
                "$categories" "$purity" "$sorting" "$order" "$resolution" "$ratio" \
                "$top_range" "$random_seed"
            command rm -f -- "$new_rows"
            __wallhaven_restore_previous_filters \
                "$state" 'Request failed — previous results kept'
            __wallhaven_emit_results "$rows"
            return
        end

        if test "$sorting" = random; and test -z "$random_seed"
            set random_seed (command jq -r '.meta.seed // empty' "$response")
        end
        set current_page (command jq -r '.meta.current_page // 1' "$response")
        set last_page (command jq -r '.meta.last_page // 1' "$response")

        if not test -s "$new_rows"; or test "$current_page" -ge "$last_page"
            break
        end
        set current_page (math "$current_page + 1")
    end

    command mv -- "$new_rows" "$rows"
    set -l notice
    if not test -s "$rows"
        set notice 'No results — edit the search or filters'
    end

    set -l updated_state (command mktemp "$state.XXXXXX")
    command jq \
        --arg query "$requested_query" \
        --arg resolution "$resolution" \
        --arg ratio "$ratio" \
        --arg categories "$categories" \
        --arg purity "$purity" \
        --arg random_seed "$random_seed" \
        --arg notice "$notice" \
        --argjson first "$first_page" \
        --argjson current "$current_page" \
        --argjson last "$last_page" '
            .query = $query
            | .resolution = $resolution
            | .ratio = $ratio
            | .categories = $categories
            | .purity = $purity
            | .random_seed = $random_seed
            | .first = $first
            | .current = $current
            | .last = $last
            | .requested_start = 1
            | .notice = $notice
            | .notice_temporary = false
            | .focus_first = true
            | .pending_filters = false
            | del(.previous_filters)
        ' "$state" >"$updated_state"
    and command mv -- "$updated_state" "$state"

    __wallhaven_emit_results "$rows"
end

function __wallhaven_edit_filters --argument-names state
    set -l updated (__wallhaven_filter_menu \
        (command jq -r '
            .resolution_mode,
            .auto_resolution,
            .ratio_mode,
            .auto_ratio,
            .sorting,
            .order,
            .categories_filter,
            .purity_filter,
            .top_range
        ' "$state"))
    or return

    set -l fields (string split \t -- "$updated")
    set -l updated_state (command mktemp "$state.XXXXXX")
    command jq \
        --arg resolution_mode "$fields[1]" \
        --arg ratio_mode "$fields[2]" \
        --arg sorting "$fields[3]" \
        --arg order "$fields[4]" \
        --arg categories_filter "$fields[5]" \
        --arg purity_filter "$fields[6]" \
        --arg top_range "$fields[7]" '
            .previous_filters = {
                resolution_mode: .resolution_mode,
                ratio_mode: .ratio_mode,
                sorting: .sorting,
                order: .order,
                categories_filter: .categories_filter,
                purity_filter: .purity_filter,
                top_range: .top_range
            }
            | .resolution_mode = $resolution_mode
            | .ratio_mode = $ratio_mode
            | .sorting = $sorting
            | .order = $order
            | .categories_filter = $categories_filter
            | .purity_filter = $purity_filter
            | .top_range = $top_range
            | .pending_filters = true
            | .notice = ""
            | .notice_temporary = false
        ' "$state" >"$updated_state"
    and command mv -- "$updated_state" "$state"
end

function __wallhaven_apply_filters --argument-names state rows temporary_dir
    if test (command jq -r '.pending_filters // false' "$state") != true
        __wallhaven_emit_results "$rows"
        return
    end

    set -l query (command jq -r '.query // ""' "$state")
    __wallhaven_refresh_results "$state" "$rows" "$temporary_dir" "$query"
end

function __wallhaven_relax_filters --argument-names state rows temporary_dir
    set -l updated_state (command mktemp "$state.XXXXXX")
    command jq '
        .previous_filters = {
            resolution_mode: .resolution_mode,
            ratio_mode: .ratio_mode,
            sorting: .sorting,
            order: .order,
            categories_filter: .categories_filter,
            purity_filter: .purity_filter,
            top_range: .top_range
        }
        | .resolution_mode = "any"
        | .ratio_mode = "any"
        | .pending_filters = true
        | .notice = ""
        | .notice_temporary = false
    ' "$state" >"$updated_state"
    and command mv -- "$updated_state" "$state"

    __wallhaven_apply_filters "$state" "$rows" "$temporary_dir"
end

function __wallhaven_display_resolution
    if set -q WALLHAVEN_RESOLUTION; and string match -qr '^[1-9][0-9]*x[1-9][0-9]*$' -- "$WALLHAVEN_RESOLUTION"
        printf '%s\n' "$WALLHAVEN_RESOLUTION"
        return
    end

    set -l resolutions
    if command -q kscreen-doctor
        set resolutions (command kscreen-doctor -o 2>/dev/null |
            string match -rag '([0-9]+x[0-9]+)@[0-9.]+\*')
        if test (count $resolutions) -eq 0
            set resolutions (command kscreen-doctor -o 2>/dev/null |
                string match -rag 'Geometry: [^ ]+ ([0-9]+x[0-9]+)')
        end
    end

    if test (count $resolutions) -eq 0; and command -q xrandr
        set resolutions (command xrandr --current 2>/dev/null |
            string match -rag ' ([0-9]+x[0-9]+)\+[0-9]+\+[0-9]+')
    end

    set -l best 1920x1080
    set -l best_area 0
    for resolution in $resolutions
        set -l dimensions (string split x -- "$resolution")
        set -l area (math "$dimensions[1] * $dimensions[2]")
        if test "$area" -gt "$best_area"
            set best "$resolution"
            set best_area "$area"
        end
    end

    printf '%s\n' "$best"
end

function __wallhaven_aspect_ratio --argument-names resolution
    if not string match -qr '^[1-9][0-9]*x[1-9][0-9]*$' -- "$resolution"
        return 2
    end

    set -l dimensions (string split x -- "$resolution")
    set -l width "$dimensions[1]"
    set -l height "$dimensions[2]"
    set -l left "$width"
    set -l right "$height"

    while test "$right" -ne 0
        set -l remainder (math "$left % $right")
        set left "$right"
        set right "$remainder"
    end

    printf '%sx%s\n' (math "$width / $left") (math "$height / $left")
end

function __wallhaven_filter_bits --argument-names kind value
    set value (string lower -- "$value")
    if string match -qr '^[01]{3}$' -- "$value"
        printf '%s\n' "$value"
        return
    end

    set -l first
    set -l second
    set -l third
    switch "$kind"
        case purity
            set first sfw
            set second sketchy
            set third nsfw
        case categories
            set first general
            set second anime
            set third people
    end

    set -l values (string split , -- "$value")
    for item in $values
        if not contains -- "$item" "$first" "$second" "$third"
            printf 'wallhaven: invalid %s filter: %s\n' "$kind" "$value" >&2
            return 2
        end
    end

    printf '%d%d%d\n' \
        (contains -- "$first" $values; and echo 1; or echo 0) \
        (contains -- "$second" $values; and echo 1; or echo 0) \
        (contains -- "$third" $values; and echo 1; or echo 0)
end

function __wallhaven_filter_label --argument-names kind value auto_resolution
    switch "$kind"
        case resolution
            switch "$value"
                case any
                    printf 'Any\n'
                case auto
                    printf 'Auto (%s)\n' (string replace x '×' -- "$auto_resolution")
                case '*'
                    printf '%s+\n' (string replace x '×' -- "$value")
            end
        case ratio
            switch "$value"
                case any
                    printf 'Any\n'
                case auto
                    printf 'Auto (%s)\n' (string replace x ':' -- "$auto_resolution")
                case '*'
                    printf '%s\n' (string replace x ':' -- "$value")
            end
        case sorting
            switch "$value"
                case date_added
                    printf 'Latest\n'
                case toplist
                    printf 'Toplist\n'
                case '*'
                    printf '%s%s\n' \
                        (string upper -- (string sub --length 1 "$value")) \
                        (string sub --start 2 "$value")
            end
        case order
            if test "$value" = desc
                printf 'Descending\n'
            else
                printf 'Ascending\n'
            end
        case categories purity
            printf '%s\n' (string replace -a , ' + ' -- "$value")
    end
end

function __wallhaven_pick --argument-names title current
    set -l selected (
        begin
            for option in $argv[3..-1]
                set -l fields (string split :: -- "$option")
                if test "$fields[1]" = "$current"
                    printf '●\t%s\t%s\n' "$fields[2]" "$fields[1]"
                end
            end
            for option in $argv[3..-1]
                set -l fields (string split :: -- "$option")
                if test "$fields[1]" != "$current"
                    printf ' \t%s\t%s\n' "$fields[2]" "$fields[1]"
                end
            end
        end |
            command fzf \
                --height=60% \
                --layout=reverse \
                --border=rounded \
                --border-label=" $title " \
                --delimiter=\t \
                --with-nth=1,2 \
                --prompt='Choose> ' \
                --no-multi \
                --cycle
    )
    or return

    set -l fields (string split \t -- "$selected")
    printf '%s\n' "$fields[3]"
end

function __wallhaven_filter_menu --argument-names \
    resolution_mode auto_resolution ratio auto_ratio sorting order \
    categories_filter purity_filter top_range
    while true
        set -l resolution_label \
            (__wallhaven_filter_label resolution "$resolution_mode" "$auto_resolution")
        set -l ratio_label (__wallhaven_filter_label ratio "$ratio" "$auto_ratio")
        set -l sorting_label (__wallhaven_filter_label sorting "$sorting")
        set -l order_label (__wallhaven_filter_label order "$order")
        set -l categories_label (__wallhaven_filter_label categories "$categories_filter")
        set -l purity_label (__wallhaven_filter_label purity "$purity_filter")

        set -l selected (
            begin
                printf '%-24s%s\t%s\n' SETTING VALUE __header__
                printf '%-24s%s\t%s\n' 'Apply filters' 'Fetch updated results' apply
                printf '%-24s%s\t%s\n' 'Minimum resolution' "$resolution_label" resolution
                printf '%-24s%s\t%s\n' 'Aspect ratio' "$ratio_label" ratio
                printf '%-24s%s\t%s\n' 'Sort by' "$sorting_label" sorting
                printf '%-24s%s\t%s\n' 'Order' "$order_label" order
                printf '%-24s%s\t%s\n' 'Categories' "$categories_label" categories
                printf '%-24s%s\t%s\n' 'Purity' "$purity_label" purity
                if test "$sorting" = toplist
                    printf '%-24s%s\t%s\n' 'Toplist period' "$top_range" top_range
                end
                printf '%-24s%s\t%s\n' 'Reset filters' 'Restore defaults' reset
            end |
                command fzf \
                    --height=75% \
                    --layout=reverse \
                    --border=rounded \
                    --border-label=' Wallhaven filters ' \
                    --border-label-pos=2 \
                    --delimiter=\t \
                    --with-nth=1 \
                    --header-lines=1 \
                    --header-lines-border=bottom \
                    --no-input \
                    --info=hidden \
                    --footer='Enter: edit · Esc: keep current filters' \
                    --footer-border=line \
                    --no-multi
        )
        or return

        set -l fields (string split \t -- "$selected")
        switch "$fields[2]"
            case apply
                printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                    "$resolution_mode" "$ratio" "$sorting" "$order" \
                    "$categories_filter" "$purity_filter" "$top_range"
                return
            case resolution
                set -l picked (__wallhaven_pick 'Minimum resolution' "$resolution_mode" \
                    'any::Any' \
                    (printf 'auto::Auto (%s)\n' (string replace x '×' -- "$auto_resolution")) \
                    '1920x1080::1920×1080 · Full HD' \
                    '2560x1440::2560×1440 · QHD' \
                    '3440x1440::3440×1440 · Ultrawide' \
                    '3840x2160::3840×2160 · 4K' \
                    '5120x1440::5120×1440 · Dual QHD' \
                    '5120x2880::5120×2880 · 5K' \
                    '7680x4320::7680×4320 · 8K')
                and set resolution_mode "$picked"
            case ratio
                set -l picked (__wallhaven_pick 'Aspect ratio' "$ratio" \
                    (printf 'auto::Auto (%s)\n' (string replace x ':' -- "$auto_ratio")) \
                    'any::Any' \
                    '16x9::16:9 · Widescreen' \
                    '16x10::16:10' \
                    '21x9::21:9 · Ultrawide' \
                    '32x9::32:9 · Super ultrawide' \
                    '48x9::48:9 · Triple display' \
                    '4x3::4:3 · Classic' \
                    '5x4::5:4' \
                    '9x16::9:16 · Portrait' \
                    '10x16::10:16 · Portrait')
                and set ratio "$picked"
            case sorting
                set -l picked (__wallhaven_pick 'Sort by' "$sorting" \
                    'date_added::Latest' \
                    'relevance::Relevance' \
                    'random::Random' \
                    'views::Most viewed' \
                    'favorites::Most favorited' \
                    'toplist::Toplist')
                and set sorting "$picked"
            case order
                set -l picked (__wallhaven_pick 'Order' "$order" \
                    'desc::Descending' \
                    'asc::Ascending')
                and set order "$picked"
            case categories
                set -l picked (__wallhaven_pick 'Categories' "$categories_filter" \
                    'general,anime,people::All categories' \
                    'general::General' \
                    'anime::Anime' \
                    'people::People' \
                    'general,anime::General + anime' \
                    'general,people::General + people' \
                    'anime,people::Anime + people')
                and set categories_filter "$picked"
            case purity
                set -l purity_options \
                    'sfw::SFW' \
                    'sketchy::Sketchy' \
                    'sfw,sketchy::SFW + sketchy'
                if set -q WALLHAVEN_API_KEY; and test -n "$WALLHAVEN_API_KEY"
                    set -a purity_options \
                        'sfw,sketchy,nsfw::SFW + sketchy + NSFW' \
                        'sfw,nsfw::SFW + NSFW' \
                        'sketchy,nsfw::Sketchy + NSFW' \
                        'nsfw::NSFW only'
                end
                set -l picked (__wallhaven_pick 'Purity' "$purity_filter" $purity_options)
                and set purity_filter "$picked"
            case top_range
                set -l picked (__wallhaven_pick 'Toplist period' "$top_range" \
                    '1d::Past day' \
                    '3d::Past 3 days' \
                    '1w::Past week' \
                    '1M::Past month' \
                    '3M::Past 3 months' \
                    '6M::Past 6 months' \
                    '1y::Past year')
                and set top_range "$picked"
            case reset
                set resolution_mode auto
                set ratio auto
                set sorting date_added
                set order desc
                set categories_filter general,anime,people
                set purity_filter sfw
                set top_range 1M
        end
    end
end

function __wallhaven_preview --argument-names \
    id thumbnail resolution category purity file_size views favorites created_at
    set -l cache_dir (__wallhaven_cache_home)/previews
    set -l preview_file "$cache_dir/$id.jpg"
    command mkdir -p -- "$cache_dir"
    or return

    if not test -s "$preview_file"
        set -l temporary "$preview_file.$fish_pid.tmp"
        if command curl --fail --silent --show-error --location --max-time 30 \
                --output "$temporary" "$thumbnail"
            command mv -f -- "$temporary" "$preview_file"
        else
            command rm -f -- "$temporary"
            printf 'Preview unavailable for %s\n' "$id"
            return 1
        end
    end

    printf '\033[1m%s\033[0m · %s · %s/%s\n' \
        "$id" (string replace x '×' -- "$resolution") "$category" "$purity"
    printf '%s favs · %s views · %s · %s\n\n' \
        "$favorites" "$views" "$created_at" "$file_size"

    set -l preview_columns "$FZF_PREVIEW_COLUMNS"
    set -l preview_lines "$FZF_PREVIEW_LINES"
    if not string match -qr '^[1-9][0-9]*$' -- "$preview_columns"
        set preview_columns 80
    end
    if not string match -qr '^[1-9][0-9]*$' -- "$preview_lines"
        set preview_lines 30
    end
    set -l image_lines (math "max(5, $preview_lines - 3)")

    if command -q kitten; and set -q KITTY_WINDOW_ID
        kitten icat --clear --transfer-mode=memory --unicode-placeholder \
            --scale-up --stdin=no \
            --place="$preview_columns"x"$image_lines"@0x0 "$preview_file" |
            command sed '$d' |
            command sed '$s/$/\x1b[m/'
    else if test -x /usr/share/fzf/fzf-preview.sh
        /usr/share/fzf/fzf-preview.sh "$preview_file"
    else if command -q kitten
        kitten icat --clear --transfer-mode=memory --unicode-placeholder --scale-up \
            --stdin=no --place="$preview_columns"x"$image_lines"@0x0 "$preview_file"
    else if command -q chafa
        chafa --size="$preview_columns"x"$image_lines" \
            "$preview_file"
    else
        command file --brief -- "$preview_file"
        printf '\nInstall chafa or run this command in Kitty for image previews.\n'
    end
end

function __wallhaven_download --argument-names image_url
    if test -z "$image_url"
        return 2
    end

    set -l download_dir (__wallhaven_download_dir)
    command mkdir -p -- "$download_dir"
    or return
    set -l destination "$download_dir/"(path basename "$image_url")

    if test -s "$destination"
        printf 'exists\t%s\n' "$destination"
        return
    end

    set -l temporary "$destination.$fish_pid.tmp"
    if command curl --fail --silent --show-error --location \
            --output "$temporary" "$image_url"
        command mv -f -- "$temporary" "$destination"
        printf 'downloaded\t%s\n' "$destination"
    else
        command rm -f -- "$temporary"
        return 1
    end
end

function __wallhaven_download_and_emit --argument-names state rows image_url
    set -l result (__wallhaven_download "$image_url")
    set -l download_status $status
    set -l notice

    if test "$download_status" -eq 0
        set -l fields (string split \t -- "$result")
        if test "$fields[1]" = exists
            set notice 'Already downloaded ✓'
        else
            set notice 'Downloaded ✓'
        end
    else
        set notice 'Download failed'
    end

    set -l updated_state (command mktemp "$state.XXXXXX")
    command jq --arg notice "$notice" '
        .notice = $notice
        | .notice_temporary = true
    ' \
        "$state" >"$updated_state"
    and command mv -- "$updated_state" "$state"

    __wallhaven_emit_results "$rows"
end

function __wallhaven_open --argument-names wallpaper_url
    if test -n "$wallpaper_url"; and command -q xdg-open
        command xdg-open "$wallpaper_url" >/dev/null 2>&1 &
        disown
    end
end

function wallhaven --description 'Browse Wallhaven with image previews'
    argparse \
        h/help \
        'q/query=' \
        'r/resolution=' \
        'ratio=' \
        's/sorting=' \
        'o/order=' \
        'p/page=' \
        'purity=' \
        'categories=' \
        'top-range=' \
        no-resolution \
        -- $argv
    or return 2

    if set -q _flag_help
        __wallhaven_help
        return
    end

    for dependency in curl jq fzf
        if not command -q -- "$dependency"
            printf 'wallhaven: required command not found: %s\n' "$dependency" >&2
            return 1
        end
    end

    set -l query (string join ' ' -- $argv)
    if set -q _flag_query
        if test -n "$query"
            printf 'wallhaven: use either --query or positional search terms\n' >&2
            return 2
        end
        set query "$_flag_query"
    end

    set -l auto_resolution (__wallhaven_display_resolution)
    set -l auto_ratio (__wallhaven_aspect_ratio "$auto_resolution")
    set -l resolution_mode auto
    if set -q _flag_resolution
        set resolution_mode "$_flag_resolution"
    else if set -q _flag_no_resolution
        set resolution_mode any
    end
    if not contains -- "$resolution_mode" any auto; and not string match -qr '^[1-9][0-9]*x[1-9][0-9]*$' -- "$resolution_mode"
        printf 'wallhaven: invalid resolution: %s\n' "$resolution_mode" >&2
        return 2
    end

    set -l ratio auto
    if set -q _flag_ratio
        set ratio (string lower -- "$_flag_ratio")
    end
    if not contains -- "$ratio" any auto; and not string match -qr '^[1-9][0-9]*x[1-9][0-9]*$' -- "$ratio"
        printf 'wallhaven: invalid aspect ratio: %s\n' "$ratio" >&2
        return 2
    end

    set -l sorting date_added
    if set -q _flag_sorting
        set sorting (string lower -- "$_flag_sorting")
        if test "$sorting" = latest
            set sorting date_added
        end
    end
    if not contains -- "$sorting" date_added relevance random views favorites toplist
        printf 'wallhaven: invalid sorting mode: %s\n' "$sorting" >&2
        return 2
    end

    set -l order desc
    if set -q _flag_order
        set order (string lower -- "$_flag_order")
    end
    if not contains -- "$order" desc asc
        printf 'wallhaven: invalid order: %s\n' "$order" >&2
        return 2
    end

    set -l current_page 1
    if set -q _flag_page
        set current_page "$_flag_page"
    end
    if not string match -qr '^[0-9]+$' -- "$current_page"; or test "$current_page" -lt 1
        printf 'wallhaven: page must be a positive number\n' >&2
        return 2
    end

    set -l purity_filter (set -q _flag_purity; and echo "$_flag_purity"; or echo sfw)
    set -l categories_filter \
        (set -q _flag_categories; and echo "$_flag_categories"; or echo general,anime,people)
    set -l purity (__wallhaven_filter_bits purity "$purity_filter")
    or return
    __wallhaven_filter_bits categories "$categories_filter" >/dev/null
    or return

    if string match -q '*1' -- "$purity"; and not __wallhaven_has_api_key
        printf 'wallhaven: NSFW results require WALLHAVEN_API_KEY\n' >&2
        return 2
    end

    set -l top_range 1M
    if set -q _flag_top_range
        set top_range "$_flag_top_range"
    end
    if not contains -- "$top_range" 1d 3d 1w 1M 3M 6M 1y
        printf 'wallhaven: invalid toplist range: %s\n' "$top_range" >&2
        return 2
    end

    set -l temporary_dir (command mktemp -d)
    or return
    set -l rows "$temporary_dir/results.tsv"
    set -l state "$temporary_dir/state.json"
    command touch "$rows"

    set -l resolution
    switch "$resolution_mode"
        case auto
            set resolution "$auto_resolution"
        case any
            set resolution
        case '*'
            set resolution "$resolution_mode"
    end

    set -l api_ratio
    switch "$ratio"
        case auto
            set api_ratio "$auto_ratio"
        case any
            set api_ratio
        case '*'
            set api_ratio "$ratio"
    end

    set -l categories (__wallhaven_filter_bits categories "$categories_filter")
    or return

    command jq -n \
        --arg query "$query" \
        --arg resolution_mode "$resolution_mode" \
        --arg auto_resolution "$auto_resolution" \
        --arg ratio_mode "$ratio" \
        --arg auto_ratio "$auto_ratio" \
        --arg sorting "$sorting" \
        --arg order "$order" \
        --arg categories_filter "$categories_filter" \
        --arg purity_filter "$purity_filter" \
        --arg top_range "$top_range" \
        --arg resolution "$resolution" \
        --arg ratio "$api_ratio" \
        --arg categories "$categories" \
        --arg purity "$purity" \
        --argjson requested_start "$current_page" \
        '{
            query: $query,
            resolution_mode: $resolution_mode,
            auto_resolution: $auto_resolution,
            ratio_mode: $ratio_mode,
            auto_ratio: $auto_ratio,
            sorting: $sorting,
            order: $order,
            categories_filter: $categories_filter,
            purity_filter: $purity_filter,
            top_range: $top_range,
            resolution: $resolution,
            ratio: $ratio,
            categories: $categories,
            purity: $purity,
            requested_start: $requested_start,
            first: $requested_start,
            current: $requested_start,
            last: 1,
            random_seed: "",
            notice: "",
            notice_temporary: false,
            focus_first: false,
            pending_filters: false
        }' >"$state"
    or begin
        __wallhaven_clear_temporary_directory "$temporary_dir"
        command rmdir -- "$temporary_dir"
        return 1
    end

    __wallhaven_refresh_results "$state" "$rows" "$temporary_dir" "$query" >/dev/null

    set -l preview_command \
        "fish -c '__wallhaven_preview \$argv' -- {2} {11} {3} {6} {7} {8} {9} {5} {10}"
    set -l open_command \
        "fish -c '__wallhaven_open \$argv' -- {12}"
    set -l load_more_command (string join ' ' -- \
        (string escape -- fish -c '__wallhaven_load_more $argv' -- \
            "$state" "$rows" "$temporary_dir"))
    set -l search_command (string join ' ' -- \
        (string escape -- fish -c '__wallhaven_refresh_results $argv' -- \
            "$state" "$rows" "$temporary_dir"))' {q}'
    set -l download_command (string join ' ' -- \
        (string escape -- fish -c '__wallhaven_download_and_emit $argv' -- \
            "$state" "$rows"))' {13}'
    set -l edit_filters_command (string join ' ' -- \
        (string escape -- fish -c '__wallhaven_edit_filters $argv' -- "$state"))
    set -l apply_filters_command (string join ' ' -- \
        (string escape -- fish -c '__wallhaven_apply_filters $argv' -- \
            "$state" "$rows" "$temporary_dir"))
    set -l relax_filters_command (string join ' ' -- \
        (string escape -- fish -c '__wallhaven_relax_filters $argv' -- \
            "$state" "$rows" "$temporary_dir"))
    set -l input_label_command (string join ' ' -- \
        (string escape -- fish -c '__wallhaven_state_input_label $argv' -- "$state"))
    set -l border_label_command (string join ' ' -- \
        (string escape -- fish -c '__wallhaven_state_border_label $argv' -- "$state"))
    set -l clear_notice_command (string join ' ' -- \
        (string escape -- fish -c '__wallhaven_clear_temporary_notice $argv' -- "$state"))
    set -l after_load_command (string join ' ' -- \
        (string escape -- fish -c '__wallhaven_after_load $argv' -- "$state"))

    set -l input_label (__wallhaven_state_input_label "$state")
    set -l border_label (__wallhaven_state_border_label "$state")

    __wallhaven_emit_results "$rows" |
        command fzf \
            --ansi \
            --delimiter=\t \
            --with-nth=1 \
            --id-nth=2 \
            --layout=reverse \
            --info=inline-right \
            --prompt='Filter / search> ' \
            --border=rounded \
            --border-label="$border_label" \
            --border-label-pos=-2:bottom \
            --input-border=rounded \
            --input-label="$input_label" \
            --list-border=none \
            --header-lines=1 \
            --header-lines-border=bottom \
            --preview="$preview_command" \
            --preview-window='right,60%,border-left' \
            --bind="load:transform-input-label($input_label_command)+transform-border-label($border_label_command)+transform($after_load_command)+bg-transform-border-label($clear_notice_command)" \
            --bind="enter:change-border-label( Searching… )+reload-sync($search_command)+clear-query" \
            --bind="ctrl-o:execute-silent($open_command)" \
            --bind="ctrl-p:toggle-preview" \
            --bind="ctrl-r:change-border-label( Relaxing filters… )+reload-sync($relax_filters_command)+clear-query" \
            --bind="ctrl-d:change-border-label( Downloading… )+track-current+reload-sync($download_command)" \
            --bind="f2:execute($edit_filters_command)+track-current+reload-sync($apply_filters_command)+clear-query" \
            --bind="alt-right:change-border-label( Loading more… )+track-current+reload-sync($load_more_command)"
    set -l fzf_status $status

    __wallhaven_clear_temporary_directory "$temporary_dir"
    command rmdir -- "$temporary_dir"
    return "$fzf_status"
end

complete --command wallhaven --no-files
complete --command wallhaven --short-option h --long-option help \
    --description 'Show help'
complete --command wallhaven --short-option q --long-option query \
    --require-parameter --description 'Search terms'
complete --command wallhaven --short-option r --long-option resolution \
    --require-parameter --description 'Minimum resolution'
complete --command wallhaven --long-option ratio --require-parameter \
    --arguments 'auto any 16x9 16x10 21x9 32x9 48x9 4x3 5x4 9x16 10x16' \
    --description 'Aspect ratio'
complete --command wallhaven --long-option no-resolution \
    --description 'Disable resolution filtering'
complete --command wallhaven --short-option s --long-option sorting \
    --require-parameter --arguments 'latest relevance random views favorites toplist' \
    --description 'Sort order'
complete --command wallhaven --short-option o --long-option order \
    --require-parameter --arguments 'desc asc' --description 'Result order'
complete --command wallhaven --short-option p --long-option page \
    --require-parameter --description 'Initial results page'
complete --command wallhaven --long-option purity --require-parameter \
    --arguments 'sfw sfw,sketchy sfw,sketchy,nsfw' --description 'Purity filter'
complete --command wallhaven --long-option categories --require-parameter \
    --arguments 'general anime people general,anime general,anime,people' \
    --description 'Category filter'
complete --command wallhaven --long-option top-range --require-parameter \
    --arguments '1d 3d 1w 1M 3M 6M 1y' --description 'Toplist time range'
