function lb2mb_setlist --description "Convert a ListenBrainz playlist to a MusicBrainz Event setlist"
    if test (count $argv) -lt 1
        echo "Usage: lb2mb_setlist <playlist_id_or_url> [event_id_or_url]"
        return 1
    end

    set -l playlist_input $argv[1]
    set -l playlist_id (echo $playlist_input | sed -E 's|.*/playlist/([^/]+)/?|\1|')
    set -l event_id ""
    if test (count $argv) -ge 2
        set -l event_input $argv[2]
        set event_id (echo $event_input | sed -E 's|.*/event/([^/]+)/?|\1|')
    end

    # Define User-Agent to comply with MusicBrainz API policies
    set -l mb_user_agent "User-Agent: lb2mb_setlist/1.0 ( ege@celikci.me )"

    echo "Fetching playlist $playlist_id from ListenBrainz…" >&2
    set -l playlist_json (curl -s -H "$mb_user_agent" "https://api.listenbrainz.org/1/playlist/$playlist_id")

    if test -z "$playlist_json"; or test (echo "$playlist_json" | jq -r '.playlist | . == null') = "true"
        echo "Error: Could not fetch playlist. Is the ID correct?" >&2
        return 1
    end

    set -l event_artist_mbid ""
    set -l event_artist_name ""

    if test -n "$event_id"
        echo "Fetching event $event_id from MusicBrainz…" >&2
        set -l event_json (curl -s -H "$mb_user_agent" "https://musicbrainz.org/ws/2/event/$event_id?inc=artist-rels&fmt=json")
        set event_artist_mbid (echo "$event_json" | jq -r '.relations[] | select(.type == "main performer") | .artist.id' | head -n1)
        set event_artist_name (echo "$event_json" | jq -r '.relations[] | select(.type == "main performer") | .artist.name' | head -n1)

        if test -z "$event_artist_mbid"
            echo "Warning: Could not find main performer for event $event_id. Falling back to detection." >&2
        end
    end

    if test -z "$event_artist_mbid"
        echo "Determining the main performer from playlist…" >&2
        set event_artist_mbid (echo "$playlist_json" | jq -r '.playlist.track[].extension."https://musicbrainz.org/doc/jspf#track".additional_metadata.artists[0].artist_mbid' | sort | uniq -c | sort -nr | head -n1 | awk '{print $2}')
        set event_artist_name (echo "$playlist_json" | jq -r ".playlist.track[].extension.\"https://musicbrainz.org/doc/jspf#track\".additional_metadata.artists[] | select(.artist_mbid == \"$event_artist_mbid\") | .artist_credit_name" | head -n1)
    end

    set -l output "@ [$event_artist_mbid|$event_artist_name]"
    set -l warnings

    echo "Processing tracks (with MusicBrainz rate limiting)…" >&2

    set -l track_count (echo "$playlist_json" | jq '.playlist.track | length')

    if test -z "$track_count"; or test "$track_count" -eq 0
        echo "Error: Playlist is empty or track count could not be determined." >&2
        return 1
    end

    for i in (seq 0 (math $track_count - 1))
        set -l track (echo "$playlist_json" | jq -c ".playlist.track[$i]")
        set -l title (echo "$track" | jq -r '.title')
        set -l artist_name (echo "$track" | jq -r '.extension."https://musicbrainz.org/doc/jspf#track".additional_metadata.artists[0].artist_credit_name')
        set -l artist_mbid (echo "$track" | jq -r '.extension."https://musicbrainz.org/doc/jspf#track".additional_metadata.artists[0].artist_mbid')
        set -l recording_url (echo "$track" | jq -r '.identifier[0]')
        set -l recording_mbid (echo "$recording_url" | sed -E 's|.*/recording/([^/]+)|\1|')

        # Check for Work ID on MusicBrainz
        sleep 1.1
        set -l mb_json (curl -s -H "$mb_user_agent" "https://musicbrainz.org/ws/2/recording/$recording_mbid?inc=work-rels&fmt=json")
        set -l work_id (echo "$mb_json" | jq -r '.relations[]? | select(.type == "performance" and ."target-type" == "work") | .work.id' | head -n1)
        set -l work_title (echo "$mb_json" | jq -r '.relations[]? | select(.type == "performance" and ."target-type" == "work") | .work.title' | head -n1)

        set -l track_entry ""
        if test -n "$work_id"; and test "$work_id" != "null"
            set track_entry "[$work_id|$work_title]"
        else
            set track_entry "$title"
            set warnings $warnings "Warning: No Work ID found for '$title' ($recording_url). Please link it on MusicBrainz!"
        end

        set output $output "* $track_entry"
    end

    printf "\n--- GENERATED SETLIST ---\n" >&2
    for line in $output
        echo $line
    end

    if test (count $warnings) -gt 0
        printf "\n--- WARNINGS ---\n" >&2
        for w in $warnings
            echo $w >&2
        end
    end
end
