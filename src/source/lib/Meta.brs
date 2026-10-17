' Seasons, episodes and Stremio video ids ("tt123:season:episode").

function Meta_parseVideoId(id as string) as dynamic
    if Left(id, 2) <> "tt" then return invalid
    parts = id.Split(":")
    if parts.Count() < 3 then return invalid
    return { season: parts[1].ToInt(), episode: parts[2].ToInt() }
end function

function Meta_seasons(videos as object) as object
    seen = {}
    list = []
    hasSpecials = false
    for each v in videos
        key = v.season.ToStr()
        if not seen.DoesExist(key)
            seen[key] = true
            if v.season = 0 then hasSpecials = true else list.Push(v.season)
        end if
    end for
    list.Sort()
    if hasSpecials then list.Push(0)
    return list
end function

function Meta_episodes(videos as object, season as integer) as object
    out = []
    for each v in videos
        if v.season = season then out.Push(v)
    end for
    out.SortBy("episode")
    return out
end function

function Meta_indexOfVideo(episodes as object, videoId as string) as integer
    for i = 0 to episodes.Count() - 1
        if episodes[i].id = videoId then return i
    end for
    return 0
end function

function Meta_str(x as dynamic) as string
    if GetInterface(x, "ifString") <> invalid then return x
    return ""
end function

' The saga part of a title: "Spider-Man: Sin camino a casa" -> "Spider-Man".
function Meta_baseName(name as string) as string
    cut = Len(name)
    colon = Instr(1, name, ":")
    dash = Instr(1, name, " - ")
    if colon > 0 and colon - 1 < cut then cut = colon - 1
    if dash > 0 and dash - 1 < cut then cut = dash - 1
    return Left(name, cut).Trim()
end function

' Related titles for "Más de…": named like baseName (search also matches descriptions and other titles),
' without the current one or unreleased ones, newest first (no year last).
function Meta_related(metas as object, selfId as string, baseName as string, todayIso as string) as object
    thisYear = Left(todayIso, 4)
    base = LCase(baseName)
    wrapped = []
    for each meta in metas
        released = Meta_str(meta.released)
        year = Left(Meta_str(meta.year), 4)
        upcoming = (released <> "" and released > todayIso) or (released = "" and year <> "" and year > thisYear)
        named = Instr(1, LCase(Meta_str(meta.name)), base) > 0
        if Meta_str(meta.id) <> selfId and named and not upcoming
            sortKey = year
            if sortKey = "" then sortKey = "0000"
            wrapped.Push({ key: sortKey, meta: meta })
        end if
    end for
    wrapped.SortBy("key", "r")
    out = []
    for each w in wrapped
        out.Push(w.meta)
    end for
    return out
end function

' The episode after currentId in season/episode order, if it is a regular, already released one.
' An episode without a release date counts as released.
function Meta_isReleased(ep as object, todayIso as string) as boolean
    released = Meta_str(ep.released)
    return released = "" or released <= todayIso
end function

function Meta_nextEpisode(videos as object, currentId as string, todayIso as string) as dynamic
    for i = 0 to videos.Count() - 2
        if Meta_str(videos[i].id) = currentId
            candidate = videos[i + 1]
            if candidate.season = 0 or not Meta_isReleased(candidate, todayIso) then return invalid
            return candidate
        end if
    end for
    return invalid
end function
