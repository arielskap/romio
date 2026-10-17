' Stremio library items: continue watching, progress updates, pending queue.
' Times are milliseconds, as stored by Stremio. Items are written back to Stremio,
' so camelCase keys are quoted and updated with brackets (dot-assignment lowercases keys).

function Library_num(x as dynamic) as dynamic
    if GetInterface(x, "ifInt") <> invalid or GetInterface(x, "ifLongInt") <> invalid or GetInterface(x, "ifFloat") <> invalid or GetInterface(x, "ifDouble") <> invalid then return x
    return 0
end function

function Library_str(x as dynamic) as string
    if GetInterface(x, "ifString") <> invalid then return x
    return ""
end function

function Library_bool(x as dynamic) as boolean
    return GetInterface(x, "ifBoolean") <> invalid and x
end function

function Library_isActive(item as object) as boolean
    return not Library_bool(item.removed) or Library_bool(item.temp)
end function

function Library_continueWatching(items as object) as object
    wrapped = []
    for each it in items
        ' Screens compare type and show name, so items missing them are skipped instead of crashing.
        if type(it) = "roAssociativeArray" and type(it.state) = "roAssociativeArray" and Library_str(it.type) <> "" and Library_str(it.name) <> "" and Library_isActive(it)
            st = it.state
            if Library_num(st.timeOffset) > 0 and Library_str(st.video_id) <> ""
                wrapped.Push({ lw: Library_str(st.lastWatched), item: it })
            end if
        end if
    end for
    wrapped.SortBy("lw", "r")
    out = []
    for each w in wrapped
        out.Push(w.item)
    end for
    return out
end function

function Library_continueLabel(item as object) as string
    st = item.state
    time = Format_time(Library_num(st.timeOffset))
    if item.type = "series"
        ep = Meta_parseVideoId(Library_str(st.video_id))
        if ep <> invalid then return "T" + ep.season.ToStr() + " E" + ep.episode.ToStr() + " · " + time
    end if
    if Library_num(st.duration) > 0 then return time + " de " + Format_time(st.duration)
    return time
end function

' Items the user saved in Stremio (not removed, not temp), newest first. kind "" means every type.
function Library_myList(items as object, kind as string) as object
    wrapped = []
    for each it in items
        if type(it) = "roAssociativeArray" and Library_str(it._id) <> "" and Library_str(it.name) <> "" and Library_str(it.type) <> ""
            if Library_inList(it) and (kind = "" or it.type = kind)
                wrapped.Push({ mt: Library_str(it._mtime), item: it })
            end if
        end if
    end for
    wrapped.SortBy("mt", "r")
    out = []
    for each w in wrapped
        out.Push(w.item)
    end for
    return out
end function

' Watched fraction (0 to 1) of the item's current video.
function Library_progress(item as dynamic) as float
    if type(item) <> "roAssociativeArray" or type(item.state) <> "roAssociativeArray" then return 0.0
    duration = Library_num(item.state.duration)
    if duration <= 0 then return 0.0
    fraction = Library_num(item.state.timeOffset) / duration
    if fraction > 1 then return 1.0
    if fraction < 0 then return 0.0
    return fraction
end function

' Movies only: series keep per-episode watched flags, read in the detail screen.
function Library_isFinished(item as dynamic) as boolean
    if type(item) <> "roAssociativeArray" or Library_str(item.type) <> "movie" or type(item.state) <> "roAssociativeArray" then return false
    return Library_num(item.state.flaggedWatched) = 1 or Library_num(item.state.timesWatched) > 0
end function

function Library_heroItem(candidates as object, kind as string) as dynamic
    for each it in candidates
        if kind = "" or Library_str(it.type) = kind then return it
    end for
    return invalid
end function

function Library_inList(item as dynamic) as boolean
    return type(item) = "roAssociativeArray" and not Library_bool(item.removed) and not Library_bool(item.temp)
end function

' Deep copy with "En mi lista" toggled; progress (state) is never touched. A title never watched starts from meta.
function Library_setInList(item as dynamic, meta as object, inList as boolean, nowIso as string) as object
    if type(item) = "roAssociativeArray" then out = ParseJson(FormatJson(item)) else out = Library_newItem(meta, nowIso)
    out["removed"] = not inList
    if inList then out["temp"] = false
    out["_mtime"] = nowIso
    for each key in ["background", "logo", "year"]
        if Library_str(out[key]) = "" and Library_str(meta[key]) <> "" then out[key] = meta[key]
    end for
    return out
end function

' The more recently modified of two copies of an item (server and this Roku's unsent one), or invalid if neither exists.
function Library_newest(a as dynamic, b as dynamic) as dynamic
    if type(a) <> "roAssociativeArray" then a = invalid
    if type(b) <> "roAssociativeArray" then return a
    if a = invalid or Library_str(b._mtime) > Library_str(a._mtime) then return b
    return a
end function

function Library_find(items as object, id as string) as dynamic
    for each it in items
        if type(it) = "roAssociativeArray" and Library_str(it._id) = id then return it
    end for
    return invalid
end function

function Library_newState(nowIso as string) as object
    return {
        "lastWatched": nowIso, "timeWatched": 0, "timeOffset": 0, "overallTimeWatched": 0, "timesWatched": 0,
        "flaggedWatched": 0, "duration": 0, "video_id": "", "watched": "", "noNotif": false, "season": 0, "episode": 0
    }
end function

function Library_newItem(meta as object, nowIso as string) as object
    return {
        "_id": meta.id, "name": meta.name, "type": meta.type, "poster": Library_str(meta.poster), "posterShape": "poster",
        "background": "", "logo": "", "year": "", "removed": true, "temp": true, "_ctime": nowIso, "_mtime": nowIso,
        "state": Library_newState(nowIso)
    }
end function

' Returns a deep copy of item with updated progress; item itself is not modified.
function Library_withProgress(item as object, videoId as string, positionMs as dynamic, durationMs as dynamic, watchedMs as dynamic, nowIso as string) as object
    out = ParseJson(FormatJson(item))
    if type(out.state) <> "roAssociativeArray" then out["state"] = Library_newState(nowIso)
    st = out.state
    timeWatched = Library_num(st.timeWatched)
    if Library_str(st.video_id) <> videoId then timeWatched = 0
    st["video_id"] = videoId
    st["timeOffset"] = positionMs
    st["duration"] = durationMs
    st["lastWatched"] = nowIso
    st["timeWatched"] = timeWatched + watchedMs
    st["overallTimeWatched"] = Library_num(st.overallTimeWatched) + watchedMs
    out["_mtime"] = nowIso
    return out
end function

function Library_upsert(items as object, item as object) as object
    out = []
    replaced = false
    for each it in items
        if not replaced and type(it) = "roAssociativeArray" and Library_str(it._id) = item._id
            out.Push(item)
            replaced = true
        else
            out.Push(it)
        end if
    end for
    if not replaced then out.Push(item)
    return out
end function

' The last video played reached its end (credits included): continuing means the next one, not a replay.
function Library_atEnd(item as dynamic) as boolean
    if type(item) <> "roAssociativeArray" or type(item.state) <> "roAssociativeArray" then return false
    duration = Library_num(item.state.duration)
    return duration > 0 and Library_num(item.state.timeOffset) > duration * 0.95
end function

function Library_resumeMs(item as dynamic, videoId as string) as dynamic
    if type(item) <> "roAssociativeArray" or type(item.state) <> "roAssociativeArray" then return 0
    st = item.state
    if Library_str(st.video_id) <> videoId or Library_atEnd(item) then return 0
    return Library_num(st.timeOffset)
end function

'' After falling back from a resume point to the start, saving earlier positions would erase it.
function Library_shouldSave(fellBack as boolean, resumeMs as dynamic, positionMs as dynamic) as boolean
    return not fellBack or positionMs >= resumeMs
end function

' Pending items win only when newer than the server copy (another device may have saved since).
function Library_mergePending(serverItems as object, pending as object) as object
    toPut = []
    library = serverItems
    for each k in pending
        p = pending[k]
        current = Library_find(serverItems, Library_str(p._id))
        if current = invalid or Library_str(p._mtime) > Library_str(current._mtime)
            toPut.Push(p)
            library = Library_upsert(library, p)
        end if
    end for
    return { toPut: toPut, library: library }
end function

function Library_pendingMap(items as object) as object
    out = {}
    for each it in items
        out[Library_str(it._id)] = it
    end for
    return out
end function

' Keeps the `max` most recently modified pending items (the registry is limited to 16 KB).
function Library_capPending(pending as object, max as integer) as object
    if pending.Count() <= max then return pending
    wrapped = []
    for each k in pending
        wrapped.Push({ k: k, t: Library_str(pending[k]._mtime) })
    end for
    wrapped.SortBy("t", "r")
    out = {}
    for i = 0 to max - 1
        out[wrapped[i].k] = pending[wrapped[i].k]
    end for
    return out
end function

function Library_nowIso() as string
    return CreateObject("roDateTime").ToISOString()
end function
