' Operations executed by ApiTask. Each returns a plain result AA, never throws.

function Flows_run(op as string, args as object) as object
    if op = "login" then return Flows_login(args)
    if op = "boot" then return Flows_boot()
    if op = "catalog" then return Flows_catalog(args)
    if op = "search" then return Flows_search(args)
    if op = "meta" then return Flows_meta(args)
    if op = "streams" then return Flows_streams(args)
    if op = "play" then return Flows_play(args)
    if op = "saveProgress" then return Flows_saveProgress(args)
    if op = "setInList" then return Flows_setInList(args)
    if op = "saveSubStyle"
        Storage_set("subStyle", FormatJson({ "size": Addons_str(args.size), "background": Addons_str(args.background) }))
        return { ok: true, error: "" }
    end if
    if op = "noteFailedFile"
        Flows_noteFailedFile(Addons_str(args.filename))
        return { ok: true, error: "" }
    end if
    if op = "shiftSubtitle" then return Flows_shiftSubtitle(args)
    return { ok: false, error: "Operación desconocida: " + op }
end function

function Flows_login(args as object) as object
    r = Stremio_parseLogin(Http_request(Stremio_loginRequest(args.email, args.password)))
    if r.ok
        Storage_set("authKey", r.authKey)
        ' Only the email, never the password: the login prefills it next time.
        Storage_set("lastEmail", args.email)
    end if
    return r
end function

function Flows_boot() as object
    authKey = Storage_get("authKey")
    if authKey = "" then return { ok: false, authError: true, error: "", lastEmail: Storage_get("lastEmail") }
    res = Http_all([Stremio_addonsRequest(authKey), Stremio_libraryRequest(authKey)])
    a = Stremio_parseAddons(res[0])
    l = Stremio_parseLibrary(res[1])
    if a.authError or l.authError
        Storage_delete("authKey")
        expired = a.error
        if not a.authError then expired = l.error
        return { ok: false, authError: true, error: expired, lastEmail: Storage_get("lastEmail") }
    end if
    if not a.ok then return { ok: false, authError: false, error: a.error }
    addons = Addons_slim(a.addons)
    rdKey = Storage_get("rdKey")
    if rdKey = "" then rdKey = RD_keyFromAddons(addons)
    library = []
    ' Without the server library, pending items can't be compared, so they stay queued.
    if l.ok then library = Flows_flushPending(authKey, l.items)
    return { ok: true, authError: false, authKey: authKey, addons: addons, library: library, libraryLoaded: l.ok, rdKey: rdKey, error: "" }
end function

function Flows_catalog(args as object) as object
    resp = Http_request({ method: "GET", url: Addons_catalogUrl(args.cat, {}), timeoutMs: 10000 })
    if not resp.ok then return { ok: false, metas: [], error: resp.error }
    return { ok: true, metas: Addons_parseMetas(resp.json), error: "" }
end function

function Flows_search(args as object) as object
    reqs = []
    for each cat in Addons_searchCatalogs(args.addons)
        reqs.Push({ method: "GET", url: Addons_catalogUrl(cat, { search: args.query }), timeoutMs: 10000 })
    end for
    if reqs.Count() = 0 then return { ok: false, metas: [], error: "Ninguno de tus addons permite buscar." }
    return { ok: true, metas: Addons_mergeMetas(Http_all(reqs)), error: "" }
end function

' Tries the localized addon first and Cinemeta as the fallback, so the detail is never empty.
function Flows_meta(args as object) as object
    urls = Addons_metaUrls(args.addons, args.type, args.id)
    if urls.Count() = 0 then return { ok: false, meta: invalid, error: "Ningún addon tiene información de este título." }
    lastError = ""
    for i = 0 to urls.Count() - 1
        if i >= 2 then exit for
        resp = Http_request({ method: "GET", url: urls[i], timeoutMs: 10000 })
        if resp.ok
            meta = Addons_parseMeta(resp.json)
            if meta <> invalid then return { ok: true, meta: meta, error: "" }
            lastError = "respuesta inválida"
        else
            lastError = resp.error
        end if
    end for
    return { ok: false, meta: invalid, error: "No se pudo cargar la información (" + lastError + ")." }
end function

function Flows_streams(args as object) as object
    targets = Addons_streamTargets(args.addons, args.type, args.videoId)
    reqs = []
    names = []
    for each t in targets
        reqs.Push({ method: "GET", url: t.url, timeoutMs: 20000 })
        names.Push(t.name)
    end for
    if reqs.Count() = 0 then return { ok: false, streams: [], error: "Ninguno de tus addons ofrece fuentes para este título." }
    year = Addons_str(args.year)
    nowSec = CreateObject("roDateTime").AsSeconds()
    failing = Addons_recentFailures(Flows_loadJson("addonOutcomes"), nowSec, 6 * 3600)
    failedFiles = Addons_recentFailedFiles(Flows_loadJson("failedFiles"), nowSec, 7 * 86400)
    streams = Addons_capPerQuality(Addons_rankStreams(Addons_parseStreams(Http_all(reqs), names), year, failing, failedFiles, Addons_isTrue(args.resuming)), 50)
    if streams.Count() = 0 then return { ok: false, streams: [], error: "No hay fuentes disponibles en Real-Debrid para este título." }
    return { ok: true, streams: streams, error: "" }
end function

function Flows_play(args as object) as object
    if args.rdKey = "" then return { ok: false, keyProblem: true, error: "No encontré tu clave de Real-Debrid en tus addons." }
    ' The HEAD makes the addon add the file to Real-Debrid; the downloads list decides if it worked.
    ' Not a ranged GET: the Roku drops the Range header on the redirect and downloads the whole file.
    ' Subtitles only depend on the stream, so they load in the same batch.
    reqs = [{ method: "HEAD", url: args.stream.url, timeoutMs: 60000 }]
    names = []
    for each t in Addons_subtitleTargets(args.addons, args.type, args.videoId, args.stream.filename)
        reqs.Push({ method: "GET", url: t.url })
        names.Push(t.name)
    end for
    res = Http_all(reqs)
    subResponses = []
    for i = 1 to res.Count() - 1
        subResponses.Push(res[i])
    end for
    print "[Flows] resolve "; Addons_str(args.stream.addon); " -> "; res[0].code; " "; res[0].error
    dl = Http_request(RD_downloadsRequest(args.rdKey))
    if not dl.ok then return { ok: false, keyProblem: RD_isKeyProblem(dl), error: RD_error(dl) }
    d = RD_findDownload(dl, args.stream.filename)
    ' The addon may still be adding the file: ask once more before giving up on it.
    if d = invalid
        sleep(3000)
        retry = Http_request({ method: "HEAD", url: args.stream.url, timeoutMs: 60000 })
        print "[Flows] resolve retry -> "; retry.code; " "; retry.error
        dl = Http_request(RD_downloadsRequest(args.rdKey))
        if dl.ok then d = RD_findDownload(dl, args.stream.filename)
    end if
    Flows_noteOutcome(Addons_str(args.stream.addon), d <> invalid)
    if d = invalid then Flows_noteFailedFile(Addons_str(args.stream.filename))
    if d = invalid then return { ok: false, keyProblem: false, error: "Real-Debrid no tiene este archivo. Probá con otra fuente." }
    subs = Subs_parse(subResponses, names)
    result = { ok: true, keyProblem: false, direct: false, streamFormat: "hls", url: "", subtitles: subs, pick: Subs_pickIndex(subs), subStyle: Flows_loadJson("subStyle"), error: "" }
    ' Files the Roku decodes natively play as is: instant start and free seeking (Real-Debrid's
    ' transcode only converts in order from the start).
    container = Flows_container(args.stream.filename)
    if not Addons_isTrue(args.forceTranscode) and container <> "" and d.download <> ""
        head = Http_getBytes(d.download, "0-262143", 10000)
        info = { video: "", audio: "" }
        if head <> invalid
            if container = "mp4" then info = Flows_mp4Info(d.download, head) else info = Media_info(head.ToHexString())
        end if
        if Media_canDirect(info)
            result.direct = true
            result.streamFormat = container
            result.url = d.download
            return result
        end if
    end if
    tc = RD_parseTranscode(Http_request(RD_transcodeRequest(args.rdKey, d.id)))
    if not tc.ok then return { ok: false, keyProblem: tc.keyProblem, error: tc.error }
    result.url = tc.url
    return result
end function

' Codecs of an MP4 by walking its boxes: top level until moov, then the start of each trak (its
' stsd sits there). The index can be many MB, so codec boxes are often far past the first bytes.
function Flows_mp4Info(url as string, head as object) as object
    info = { video: "", audio: "" }
    offset = 0&
    for boxes = 1 to 12
        h = Flows_mp4Header(url, head, offset)
        if h = invalid or h.size < 8 then return info
        if h.type = "moov"
            child = offset + h.header
            moovEnd = offset + h.size
            for children = 1 to 30
                if child >= moovEnd then return info
                c = Flows_mp4Header(url, head, child)
                if c = invalid or c.size < 8 then return info
                if c.type = "trak"
                    span = c.size
                    if span > 65536 then span = 65536&
                    track = Media_info(Flows_mp4Hex(url, child, span))
                    if info.video = "" then info.video = track.video
                    if info.audio = "" then info.audio = track.audio
                    if info.video <> "" and info.audio <> "" then return info
                end if
                child = child + c.size
            end for
            return info
        end if
        offset = offset + h.size
    end for
    return info
end function

' Box header at offset, from the already-fetched head when it fits, else a 16-byte range request.
function Flows_mp4Header(url as string, head as object, offset as dynamic) as dynamic
    if offset + 16 <= head.Count() then return Media_boxHeader(head, offset)
    bytes = Http_getBytes(url, offset.ToStr() + "-" + (offset + 15).ToStr(), 10000)
    if bytes = invalid then return invalid
    return Media_boxHeader(bytes, 0)
end function

' The start of a trak as hex: always a small range request (copying bytes out of the head one by one
' is slow enough on the Roku for the system to kill the app).
function Flows_mp4Hex(url as string, offset as dynamic, length as dynamic) as string
    return Http_getHex(url, offset.ToStr() + "-" + (offset + length - 1).ToStr(), 10000)
end function

' Remembers whether each addon delivered its files, so unreliable ones rank lower for a few hours.
sub Flows_noteOutcome(addon as string, found as boolean)
    if addon = "" then return
    records = Addons_noteOutcome(Flows_loadJson("addonOutcomes"), addon, found, CreateObject("roDateTime").AsSeconds(), 6 * 3600)
    Storage_set("addonOutcomes", FormatJson(records))
end sub

' Remembers files that didn't play for a week, so the sources screen shows them gray and ranks them lower.
sub Flows_noteFailedFile(filename as string)
    if filename = "" then return
    records = Addons_noteFailedFile(Flows_loadJson("failedFiles"), filename, CreateObject("roDateTime").AsSeconds(), 15)
    Storage_set("failedFiles", FormatJson(records))
end sub

function Flows_loadJson(key as string) as object
    raw = Storage_get(key)
    if raw = "" then return {}
    data = ParseJson(raw)
    if type(data) = "roAssociativeArray" then return data
    return {}
end function

function Flows_container(filename as string) as string
    ext = LCase(Right(filename, 4))
    if ext = ".mkv" then return "mkv"
    if ext = ".mp4" then return "mp4"
    return ""
end function

' Writes a copy of the subtitle at args.url shifted by args.offsetMs and returns its tmp: path.
' A new name each time, so the Video node never reuses a cached copy.
function Flows_shiftSubtitle(args as object) as object
    resp = Http_request({ method: "GET", url: args.url, keepText: true, timeoutMs: 15000 })
    if not resp.ok or Addons_str(resp.text) = "" then return { ok: false, error: "No se pudo bajar el subtítulo." }
    if Storage_get("subSyncPath") <> "" then DeleteFile(Storage_get("subSyncPath"))
    path = "tmp:/subsync_" + CreateObject("roDateTime").AsSeconds().ToStr() + "_" + Rnd(100000).ToStr() + ".srt"
    if not WriteAsciiFile(path, Subs_shift(resp.text, args.offsetMs)) then return { ok: false, error: "No se pudo preparar el subtítulo." }
    Storage_set("subSyncPath", path)
    return { ok: true, path: path, error: "" }
end function

function Flows_loadPending() as object
    return Flows_loadJson("pending")
end function

' The only writer of the pending key: always capped, since the registry is limited to 16 KB. An item is ~550 bytes
' (more for series with many watched episodes): 12 of them plus 15 failed file names leave room for the rest.
sub Flows_storePending(pending as object)
    if pending.Count() = 0
        Storage_delete("pending")
    else
        Storage_set("pending", FormatJson(Library_capPending(pending, 12)))
    end if
end sub

' Puts items to the library; on failure keeps `keepOnFail` queued, on success clears the queue.
function Flows_putItems(authKey as string, items as object, keepOnFail as object) as object
    r = Stremio_parse(Http_request(Stremio_putLibraryRequest(authKey, items)))
    if r.ok then Flows_storePending({}) else Flows_storePending(keepOnFail)
    return r
end function

' Uploads queued progress that is newer than the server copy and returns the merged library.
function Flows_flushPending(authKey as string, serverItems as object) as object
    pending = Flows_loadPending()
    if pending.Count() = 0 then return serverItems
    merged = Library_mergePending(serverItems, pending)
    ' Items older than the server copy are dropped either way, so a later save can't push them.
    if merged.toPut.Count() = 0
        Flows_storePending({})
        return serverItems
    end if
    Flows_putItems(authKey, merged.toPut, Library_pendingMap(merged.toPut))
    return merged.library
end function

' Adds or removes a title from "Mi lista" on the freshest copy (server or this Roku's unsent one), so progress made
' on another device since boot is kept: only removed/temp/_mtime change. A failed save stays queued like progress.
function Flows_setInList(args as object) as object
    id = args.meta.id
    r = Stremio_parseLibrary(Http_request(Stremio_libraryItemRequest(args.authKey, id)))
    if not r.ok then return { ok: false, item: invalid, error: r.error }
    base = Library_newest(Library_find(r.items, id), Flows_loadPending()[id])
    item = Library_setInList(base, args.meta, args.inList, Library_nowIso())
    saved = Flows_saveProgress({ authKey: args.authKey, item: item })
    return { ok: saved.ok, item: item, error: saved.error }
end function

function Flows_saveProgress(args as object) as object
    pending = Flows_loadPending()
    pending[args.item._id] = args.item
    values = []
    for each k in pending
        values.Push(pending[k])
    end for
    return Flows_putItems(args.authKey, values, pending)
end function
