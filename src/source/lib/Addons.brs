' Stremio addon protocol: manifests, routing, URLs and response parsing.
' camelCase keys in produced AAs are quoted so they survive JSON and thread copies.

function Addons_arr(x as dynamic) as object
    if type(x) = "roArray" then return x
    return []
end function

function Addons_str(x as dynamic) as string
    if GetInterface(x, "ifString") <> invalid then return x
    return ""
end function

' Like Addons_str, but also accepts numbers (some addons send ratings and years as numbers).
function Addons_text(x as dynamic) as string
    if GetInterface(x, "ifString") <> invalid then return x
    if GetInterface(x, "ifInt") <> invalid or GetInterface(x, "ifFloat") <> invalid or GetInterface(x, "ifDouble") <> invalid then return Str(x).Trim()
    return ""
end function

function Addons_isTrue(x as dynamic) as boolean
    return GetInterface(x, "ifBoolean") <> invalid and x
end function

function Addons_contains(list as object, value as string) as boolean
    for each v in list
        if GetInterface(v, "ifString") <> invalid and v = value then return true
    end for
    return false
end function

function Addons_enc(s as string) as string
    ' One roUrlTransfer per scope: it is heavy and only used here for Escape.
    if m.addonsEscaper = invalid then m.addonsEscaper = CreateObject("roUrlTransfer")
    return m.addonsEscaper.Escape(s)
end function

' Returns the first capture group of pattern in text, or "".
function Addons_match(pattern as string, text as string) as string
    return Addons_matchRe(CreateObject("roRegex", pattern, "i"), text)
end function

function Addons_matchRe(re as object, text as string) as string
    found = re.Match(text)
    if found.Count() > 1 then return found[1]
    return ""
end function

function Addons_base(transportUrl as string) as string
    suffix = "/manifest.json"
    if Right(transportUrl, Len(suffix)) = suffix then return Left(transportUrl, Len(transportUrl) - Len(suffix))
    return transportUrl
end function

function Addons_isLocal(url as string) as boolean
    return Left(url, 16) = "http://127.0.0.1" or Left(url, 16) = "http://localhost"
end function

function Addons_slim(raw as object) as object
    out = []
    for each a in Addons_arr(raw)
        url = ""
        if type(a) = "roAssociativeArray" then url = Addons_str(a.transportUrl)
        if url <> "" and not Addons_isLocal(url) and type(a.manifest) = "roAssociativeArray"
            mf = a.manifest
            types = Addons_arr(mf.types)
            prefixes = Addons_arr(mf.idPrefixes)
            resources = []
            for each r in Addons_arr(mf.resources)
                if GetInterface(r, "ifString") <> invalid
                    resources.Push({ "name": r, "types": types, "idPrefixes": prefixes })
                else if type(r) = "roAssociativeArray" and Addons_str(r.name) <> ""
                    rt = types
                    if type(r.types) = "roArray" then rt = r.types
                    rp = prefixes
                    if type(r.idPrefixes) = "roArray" then rp = r.idPrefixes
                    resources.Push({ "name": r.name, "types": rt, "idPrefixes": rp })
                end if
            end for
            catalogs = []
            for each c in Addons_arr(mf.catalogs)
                if type(c) = "roAssociativeArray" and Addons_str(c.id) <> "" and Addons_str(c.type) <> ""
                    extras = []
                    required = []
                    for each e in Addons_arr(c.extra)
                        if type(e) = "roAssociativeArray" and Addons_str(e.name) <> ""
                            extras.Push(e.name)
                            if Addons_isTrue(e.isRequired) then required.Push(e.name)
                        end if
                    end for
                    for each n in Addons_arr(c.extraSupported)
                        if GetInterface(n, "ifString") <> invalid and not Addons_contains(extras, n) then extras.Push(n)
                    end for
                    for each n in Addons_arr(c.extraRequired)
                        if GetInterface(n, "ifString") <> invalid and not Addons_contains(required, n) then required.Push(n)
                    end for
                    catalogs.Push({ "type": c.type, "id": c.id, "name": Addons_str(c.name), "extras": extras, "required": required })
                end if
            end for
            out.Push({ "name": Addons_str(mf.name), "base": Addons_base(url), "resources": resources, "catalogs": catalogs })
        end if
    end for
    return out
end function

function Addons_prefixOk(prefixes as object, id as string) as boolean
    if prefixes.Count() = 0 then return true
    for each p in prefixes
        if GetInterface(p, "ifString") <> invalid and Left(id, Len(p)) = p then return true
    end for
    return false
end function

function Addons_supports(addon as object, resource as string, kind as string, id as string) as boolean
    for each r in addon.resources
        if r.name = resource and (r.types.Count() = 0 or Addons_contains(r.types, kind)) and Addons_prefixOk(r.idPrefixes, id) then return true
    end for
    return false
end function

function Addons_typeLabel(kind as string) as string
    if kind = "movie" then return "Películas"
    if kind = "series" then return "Series"
    return kind
end function

function Addons_catalogEntry(addon as object, c as object) as object
    name = c.name
    if name = "" then name = c.id
    return { "base": addon.base, "addonName": addon.name, "type": c.type, "id": c.id, "name": name, "title": name + " · " + Addons_typeLabel(c.type) }
end function

function Addons_homeCatalogs(addons as object) as object
    out = []
    for each a in addons
        for each c in a.catalogs
            if (c.type = "movie" or c.type = "series") and c.required.Count() = 0 then out.Push(Addons_catalogEntry(a, c))
        end for
    end for
    return out
end function

' Cinemeta last, so results deduplicated by id keep the localized title.
function Addons_searchCatalogs(addons as object) as object
    out = []
    for each a in Addons_cinemetaLast(addons)
        for each c in a.catalogs
            onlySearchRequired = true
            for each r in c.required
                if r <> "search" then onlySearchRequired = false
            end for
            if (c.type = "movie" or c.type = "series") and Addons_contains(c.extras, "search") and onlySearchRequired then out.Push(Addons_catalogEntry(a, c))
        end for
    end for
    return out
end function

function Addons_catalogUrl(cat as object, extras as object) as string
    url = cat.base + "/catalog/" + cat.type + "/" + Addons_enc(cat.id)
    parts = []
    for each k in extras
        parts.Push(k + "=" + Addons_enc(extras[k]))
    end for
    if parts.Count() > 0 then url = url + "/" + parts.Join("&")
    return url + ".json"
end function

function Addons_isCinemeta(addon as object) as boolean
    return Addons_str(addon.base).Instr("v3-cinemeta.strem.io") >= 0
end function

' Accounts list Cinemeta first, but it is English-only: other metadata addons (often localized) go before it.
function Addons_cinemetaLast(addons as object) as object
    out = []
    cinemeta = []
    for each a in addons
        if Addons_isCinemeta(a) then cinemeta.Push(a) else out.Push(a)
    end for
    out.Append(cinemeta)
    return out
end function

function Addons_metaUrls(addons as object, kind as string, id as string) as object
    out = []
    for each a in Addons_cinemetaLast(addons)
        if Addons_supports(a, "meta", kind, id) then out.Push(a.base + "/meta/" + kind + "/" + Addons_enc(id) + ".json")
    end for
    return out
end function

function Addons_streamTargets(addons as object, kind as string, videoId as string) as object
    out = []
    for each a in addons
        if Addons_supports(a, "stream", kind, videoId) then out.Push({ name: a.name, url: a.base + "/stream/" + kind + "/" + Addons_enc(videoId) + ".json" })
    end for
    return out
end function

function Addons_subtitleTargets(addons as object, kind as string, videoId as string, filename as string) as object
    out = []
    for each a in addons
        if Addons_supports(a, "subtitles", kind, videoId)
            out.Push({ name: a.name, url: a.base + "/subtitles/" + kind + "/" + Addons_enc(videoId) + "/filename=" + Addons_enc(filename) + ".json" })
        end if
    end for
    return out
end function

' Fields the home hero and the detail header show, from a catalog or full meta.
function Addons_heroFields(item as object) as object
    genres = Addons_arr(item.genres)
    if genres.Count() = 0 then genres = Addons_arr(item.genre)
    names = []
    for each g in genres
        if GetInterface(g, "ifString") <> invalid and names.Count() < 3 then names.Push(g)
    end for
    extras = item.app_extras
    if type(extras) <> "roAssociativeArray" then extras = {}
    certification = ""
    if type(extras.certifications) = "roAssociativeArray" then certification = Addons_str(extras.certifications["AR"])
    directors = []
    for each d in Addons_arr(extras.directors)
        if type(d) = "roAssociativeArray" and Addons_drawable(Addons_str(d.name)) and directors.Count() < 2 then directors.Push(d.name)
    end for
    if directors.Count() = 0
        for each d in Addons_arr(item.director)
            if directors.Count() < 2 and Addons_drawable(Addons_str(d)) then directors.Push(d)
        end for
    end if
    return {
        "description": Addons_str(item.description), "background": Addons_str(item.background), "logo": Addons_str(item.logo),
        "imdbRating": Addons_text(item.imdbRating), "year": Addons_text(item.year), "runtime": Addons_str(item.runtime), "genres": names.Join(", "),
        "certification": certification, "director": directors.Join(", ")
    }
end function

' Non-empty and drawable by the Roku system font, which covers Latin scripts but not CJK, so a Korean name would show as boxes.
function Addons_drawable(text as string) as boolean
    if text = "" then return false
    for i = 0 to Len(text) - 1
        code = Asc(Mid(text, i + 1, 1))
        ' Typographic quotes and dashes (D’Onofrio) are in the font too.
        if code > &h24F and (code < &h2010 or code > &h2027) then return false
    end for
    return true
end function

' Cast with photos, only for full metas: catalog metas would carry it for every poster on the home screen.
function Addons_cast(item as object) as object
    cast = []
    extras = item.app_extras
    if type(extras) <> "roAssociativeArray" then return cast
    for each c in Addons_arr(extras.cast)
        if type(c) = "roAssociativeArray" and Addons_str(c.photo) <> "" and Addons_drawable(Addons_str(c.name)) and cast.Count() < 15
            cast.Push({ "name": c.name, "character": Addons_str(c.character), "photo": c.photo })
        end if
    end for
    return cast
end function

function Addons_parseMetas(data as dynamic) as object
    out = []
    if type(data) <> "roAssociativeArray" then return out
    for each item in Addons_arr(data.metas)
        if out.Count() >= 50 then exit for
        if type(item) = "roAssociativeArray" and Addons_str(item.id) <> ""
            meta = { "id": item.id, "type": Addons_str(item.type), "name": Addons_str(item.name), "poster": Addons_str(item.poster), "releaseInfo": Addons_str(item.releaseInfo), "released": Addons_str(item.released) }
            meta.Append(Addons_heroFields(item))
            out.Push(meta)
        end if
    end for
    return out
end function

function Addons_mergeMetas(responses as object) as object
    out = []
    seen = {}
    for each r in responses
        if r.ok
            for each item in Addons_parseMetas(r.json)
                if not seen.DoesExist(item.id)
                    seen[item.id] = true
                    out.Push(item)
                end if
            end for
        end if
    end for
    return out
end function

function Addons_int(x as dynamic) as integer
    if GetInterface(x, "ifInt") <> invalid then return x
    if GetInterface(x, "ifString") <> invalid then return x.ToInt()
    return 0
end function

function Addons_parseMeta(data as dynamic) as dynamic
    if type(data) <> "roAssociativeArray" or type(data.meta) <> "roAssociativeArray" then return invalid
    mt = data.meta
    if Addons_str(mt.id) = "" then return invalid
    videos = []
    for each v in Addons_arr(mt.videos)
        if type(v) = "roAssociativeArray" and Addons_str(v.id) <> ""
            episode = Addons_int(v.episode)
            if episode = 0 then episode = Addons_int(v.number)
            season = Addons_int(v.season)
            title = Addons_str(v.name)
            if title = "" then title = Addons_str(v.title)
            overview = Addons_str(v.overview)
            if overview = "" then overview = Addons_str(v.description)
            videos.Push({ id: v.id, season: season, episode: episode, title: title, order: season * 10000 + episode, thumbnail: Addons_str(v.thumbnail), overview: overview, released: Addons_str(v.released) })
        end if
    end for
    videos.SortBy("order")
    meta = { "id": mt.id, "type": Addons_str(mt.type), "name": Addons_str(mt.name), "poster": Addons_str(mt.poster), "releaseInfo": Addons_str(mt.releaseInfo), "videos": videos }
    meta.Append(Addons_heroFields(mt))
    meta["cast"] = Addons_cast(mt)
    return meta
end function

' What the file name says about playing it on the Roku, compiled once per stream list.
function Addons_factsRe() as object
    return {
        convert: CreateObject("roRegex", "(x265|hevc|h\.?265|av1|vp9|10bit|10-bit|hi10|(?<![a-z])(e?-?ac-?3|ddp|dd\+|dd[0-9]|dts|truehd|atmos|flac|opus)(?![a-z]))", "i"),
        direct: CreateObject("roRegex", "(?<![a-z])(x264|h\.?264|avc)(?![a-z])", "i"),
        audio: CreateObject("roRegex", "(?<![a-z])(aac|mp3)", "i"),
        spanish: CreateObject("roRegex", "(?<![a-z])(spa|spanish|espa[nñ]ol|castellano|latino|lat|esp)(?![a-z])", "i"),
        flag: CreateObject("roRegex", "[\x{1F1E6}-\x{1F1FF}]{2}", "u"),
        dv: CreateObject("roRegex", "(?<![a-z])(dv|dovi|dolby ?vision)(?![a-z])", "i"),
        known: [
            { name: "Inglés", flags: ["🇬🇧", "🇺🇸"] }, { name: "Italiano", flags: ["🇮🇹"] }, { name: "Francés", flags: ["🇫🇷"] },
            { name: "Portugués", flags: ["🇵🇹", "🇧🇷"] }, { name: "Alemán", flags: ["🇩🇪"] }, { name: "Ruso", flags: ["🇷🇺"] }
        ]
    }
end function

' "direct" only for H.264 with AAC/MP3 audio named and nothing the Roku can't decode; anything unknown is "convert"
' (WEB releases often carry Dolby Digital Plus without saying so).
function Addons_compatWith(re as object, text as string) as string
    if re.convert.IsMatch(text) then return "convert"
    if re.direct.IsMatch(text) and re.audio.IsMatch(text) then return "direct"
    return "convert"
end function

' Audio languages from the flags addons append (and Spanish also from words), Spanish first.
function Addons_languagesWith(re as object, text as string) as object
    out = []
    esFlag = text.Instr("🇪🇸") >= 0 or text.Instr("🇲🇽") >= 0
    if esFlag or re.spanish.IsMatch(text) then out.Push("Español")
    matched = 0
    if esFlag then matched = 1
    for each lang in re.known
        for each f in lang.flags
            if text.Instr(f) >= 0
                out.Push(lang.name)
                matched = matched + 1
                exit for
            end if
        end for
    end for
    if re.flag.MatchAll(text).Count() > matched then out.Push("Otro")
    return out
end function

function Addons_parseStreams(responses as object, names as object) as object
    out = []
    ' Compiled once: addons can return hundreds of streams.
    qualityRe = CreateObject("roRegex", "(4320p|2160p|4k|1080p|720p|480p)", "i")
    sizeRe = CreateObject("roRegex", "(([0-9]+(\.[0-9]+)?) ?([GM]B))", "i")
    facts = Addons_factsRe()
    for i = 0 to responses.Count() - 1
        r = responses[i]
        if r.ok and type(r.json) = "roAssociativeArray"
            for each s in Addons_arr(r.json.streams)
                url = ""
                filename = ""
                if type(s) = "roAssociativeArray"
                    url = Addons_str(s.url)
                    if type(s.behaviorHints) = "roAssociativeArray" then filename = Addons_str(s.behaviorHints.filename)
                end if
                if Left(url, 4) = "http" and filename <> ""
                    desc = Addons_str(s.title)
                    if desc = "" then desc = Addons_str(s.description)
                    name = Addons_str(s.name).Replace(Chr(10), " ")
                    quality = LCase(Addons_matchRe(qualityRe, name + " " + filename))
                    ' Size as shown ("2.3 GB") and in MB for ranking, from one match.
                    size = ""
                    sizeMb = 0
                    sizeMatch = sizeRe.Match(desc)
                    if sizeMatch.Count() > 4
                        size = sizeMatch[1]
                        sizeMb = Int(Val(sizeMatch[2]))
                        if UCase(sizeMatch[4]) = "GB" then sizeMb = Int(Val(sizeMatch[2]) * 1024)
                    end if
                    text = filename + " " + desc
                    langs = Addons_languagesWith(facts, text)
                    hdr = ""
                    if facts.dv.IsMatch(name + " " + text)
                        hdr = "DV"
                    else if LCase(name + " " + text).Instr("hdr") >= 0
                        hdr = "HDR"
                    end if
                    cached = name.Instr("RD+") >= 0 or name.Instr("RD⚡") >= 0
                    out.Push({
                        filename: filename, url: url, addon: names[i], quality: quality, size: size, sizeMb: sizeMb, compat: Addons_compatWith(facts, text), langs: langs, spanish: langs.Count() > 0 and langs[0] = "Español",
                        hdr: hdr, cached: cached
                    })
                end if
            end for
        end if
    end for
    return out
end function

' records: addon name -> { fails, ok, at } (counts of "file not in Real-Debrid" vs found, since `at`).
' Returns name -> true for addons that, within maxAgeSec, failed at least twice and more than they worked.
function Addons_recentFailures(records as dynamic, nowSec as integer, maxAgeSec as integer) as object
    out = {}
    if type(records) <> "roAssociativeArray" then return out
    for each name in records
        r = records[name]
        if type(r) = "roAssociativeArray" and nowSec - Addons_int(r.at) <= maxAgeSec
            fails = Addons_int(r.fails)
            if fails >= 2 and fails > Addons_int(r.ok) then out[name] = true
        end if
    end for
    return out
end function

' Adds one outcome for an addon; counts older than maxAgeSec start over.
function Addons_noteOutcome(records as object, addon as string, found as boolean, nowSec as integer, maxAgeSec as integer) as object
    r = records[addon]
    if type(r) <> "roAssociativeArray" or nowSec - Addons_int(r.at) > maxAgeSec then r = { fails: 0, ok: 0, at: nowSec }
    if found then r.ok = Addons_int(r.ok) + 1 else r.fails = Addons_int(r.fails) + 1
    records[addon] = r
    return records
end function

' Copies filmed in the cinema, pre-release rips and burned-in subtitles look bad on any screen.
function Addons_lowQualityRe() as object
    return CreateObject("roRegex", "(?<![0-9a-z])(cam|camrip|hdcam|hqcam|ts|hdts|telesync|tc|hdtc|telecine|scr|screener|dvdscr|prehd|pre-hd|hc|hardsub|hardsubs|korsub)(?![0-9a-z])", "i")
end function

function Addons_isLowQualityCopy(filename as string) as boolean
    return Addons_lowQualityRe().IsMatch(filename)
end function

function Addons_otherYear(yearRe as object, filename as string, year as string) as boolean
    found = yearRe.MatchAll(filename)
    if found.Count() = 0 then return false
    for each match in found
        if match[0] = year then return false
    end for
    return true
end function

' Quality first: 1080p, then 720p, then the rest, 4K+ last (heavy to convert, no gain on screen). Within a quality,
' sources from addons that recently failed or files that failed before go after the others, then direct play before
' conversion, Spanish audio first, and lighter files first since they start sooner.
' When resuming, direct 720p/1080p sources come first: Real-Debrid's conversion rarely reaches the resume point.
' For movies, `year` sends releases of another year to the end: some addons match by title only.
' Cinema/pre-release/hardsub and 3D copies go just above other years. Each stream gets `note`: why it is shown gray.
function Addons_rankStreams(streams as object, year as string, failing as object, failedFiles as object, resuming as boolean) as object
    groups = { "1080p": 1, "720p": 2, "480p": 3, "2160p": 5, "4k": 5, "4320p": 5 }
    ' Bounded so resolutions like 1920x1080 don't read as a year.
    yearRe = CreateObject("roRegex", "(?<![0-9a-z])(19|20)[0-9][0-9](?![0-9a-z])", "i")
    lowRe = Addons_lowQualityRe()
    ' Side-by-side and over-under 3D shows two squashed pictures on a normal TV.
    threeDRe = CreateObject("roRegex", "(?<![0-9a-z])(3d|hsbs|h-sbs|half-sbs|sbs|hou|h-ou|half-ou)(?![0-9a-z])", "i")
    wrapped = []
    for i = 0 to streams.Count() - 1
        s = streams[i]
        filename = Addons_str(s.filename)
        mb = s.sizeMb
        note = ""
        failed = 0
        if failing.DoesExist(Addons_str(s.addon)) or failedFiles.DoesExist(filename)
            failed = 1
            note = "Falló la última vez"
        end if
        g = 4
        if groups.DoesExist(s.quality) then g = groups[s.quality]
        if lowRe.IsMatch(filename)
            g = 9
            if note = "" then note = "Copia de cine"
        else if threeDRe.IsMatch(filename)
            g = 9
            if note = "" then note = "Es 3D"
        end if
        if year <> "" and Addons_otherYear(yearRe, filename, year)
            g = 10
            if note = "" then note = "Es de otro año"
        end if
        ' Unknown sizes and tiny files (samples, not the movie) go last within their quality.
        tier = 0
        if mb = 0 then tier = 1
        if mb > 0 and mb < 200
            tier = 2
            if note = "" then note = "Muestra chica"
        end if
        direct = Addons_str(s.compat) = "direct"
        if resuming and direct and note = "" and (g = 1 or g = 2) then g = 0
        compat = 1
        if direct then compat = 0
        spanish = 1
        if Addons_isTrue(s.spanish) then spanish = 0
        s.note = note
        key = Right("0" + g.ToStr(), 2) + failed.ToStr() + compat.ToStr() + spanish.ToStr() + tier.ToStr() + Right("0000000" + mb.ToStr(), 7) + Right("0000" + i.ToStr(), 4)
        wrapped.Push({ key: key, stream: s })
    end for
    wrapped.SortBy("key")
    out = []
    for each w in wrapped
        out.Push(w.stream)
    end for
    return out
end function

' Files Real-Debrid didn't have or that didn't play: filename -> seconds. Keeps the `max` most recent.
function Addons_noteFailedFile(records as object, filename as string, nowSec as integer, max as integer) as object
    records[filename] = nowSec
    while records.Count() > max
        oldest = ""
        for each k in records
            if oldest = "" or Addons_int(records[k]) < Addons_int(records[oldest]) then oldest = k
        end for
        records.Delete(oldest)
    end while
    return records
end function

function Addons_recentFailedFiles(records as dynamic, nowSec as integer, maxAgeSec as integer) as object
    out = {}
    if type(records) <> "roAssociativeArray" then return out
    for each k in records
        if nowSec - Addons_int(records[k]) <= maxAgeSec then out[k] = true
    end for
    return out
end function

' Addons can return over a thousand streams: keeps the first `n` of each quality tab (1080p, 720p, 4K, others),
' so the list stays light without losing whole qualities.
function Addons_capPerQuality(streams as object, n as integer) as object
    bucketOf = { "1080p": "1080p", "720p": "720p", "2160p": "4k", "4k": "4k", "4320p": "4k" }
    counts = {}
    out = []
    for each s in streams
        bucket = "other"
        q = Addons_str(s.quality)
        if bucketOf.DoesExist(q) then bucket = bucketOf[q]
        c = 0
        if counts.DoesExist(bucket) then c = counts[bucket]
        if c < n
            out.Push(s)
            counts[bucket] = c + 1
        end if
    end for
    return out
end function
