' Subtitle addons: parsing, Spanish auto-pick and Roku track building.

function Subs_parse(responses as object, names as object) as object
    out = []
    seen = {}
    for i = 0 to responses.Count() - 1
        r = responses[i]
        if r.ok and type(r.json) = "roAssociativeArray"
            for each s in Addons_arr(r.json.subtitles)
                if type(s) = "roAssociativeArray"
                    url = Addons_str(s.url)
                    lang = Addons_str(s.lang)
                    if url <> "" and lang <> "" and not seen.DoesExist(url)
                        seen[url] = true
                        out.Push({ lang: lang, url: url, addon: names[i] })
                    end if
                end if
            end for
        end if
    end for
    return out
end function

function Subs_isSpanish(lang as string) as boolean
    l = LCase(lang)
    return l = "spa" or l = "spl" or l = "spn" or l = "es" or Left(l, 3) = "es-"
end function

function Subs_isEnglish(lang as string) as boolean
    l = LCase(lang)
    return l = "eng" or l = "en" or Left(l, 3) = "en-"
end function

' One preference rule for the auto-pick and the menu: Spanish from strem.io (re-encoded to UTF-8),
' other Spanish, English, the rest. Addons already rank by filename, so ties keep their order.
function Subs_rank(s as object) as integer
    if Subs_isSpanish(s.lang) and s.url.Instr("strem.io") >= 0 then return 0
    if Subs_isSpanish(s.lang) then return 1
    if Subs_isEnglish(s.lang) then return 2
    return 3
end function

function Subs_pickIndex(subs as object) as integer
    best = -1
    for i = 0 to subs.Count() - 1
        rank = Subs_rank(subs[i])
        if rank <= 1 and (best < 0 or rank < Subs_rank(subs[best])) then best = i
    end for
    return best
end function

' The subtitle to carry over to the next episode: the best-ranked one in the language the user chose.
function Subs_pickLang(subs as object, langName as string) as integer
    best = -1
    for i = 0 to subs.Count() - 1
        if Subs_langName(subs[i].lang) = langName and (best < 0 or Subs_rank(subs[i]) < Subs_rank(subs[best])) then best = i
    end for
    return best
end function

function Subs_menuOrder(subs as object) as object
    wrapped = []
    for i = 0 to subs.Count() - 1
        wrapped.Push({ key: Subs_rank(subs[i]).ToStr() + Right("0000" + i.ToStr(), 4), sub: subs[i] })
    end for
    wrapped.SortBy("key")
    out = []
    for each w in wrapped
        out.Push(w.sub)
    end for
    return out
end function

function Subs_langName(lang as string) as string
    if Subs_isSpanish(lang) then return "Español"
    l = LCase(lang)
    if Subs_isEnglish(lang) then return "Inglés"
    if l = "por" or l = "pob" or l = "pt" or l = "pt-br" then return "Portugués"
    return UCase(lang)
end function

' "Español · SubSense", or "Español 2 · SubSense" when a number tells repeated languages apart.
function Subs_label(s as object, number = 0 as integer) as string
    name = Subs_langName(s.lang)
    if number > 0 then name = name + " " + number.ToStr()
    return name + " · " + s.addon
end function

' Menu titles: "Sin subtítulos" first, languages numbered when repeated, the active one marked.
' activeUrl "" means subtitles are off.
function Subs_menuLabels(subs as object, activeUrl as string) as object
    totals = {}
    for each s in subs
        name = Subs_langName(s.lang)
        if totals.DoesExist(name) then totals[name] = totals[name] + 1 else totals[name] = 1
    end for
    none = "Sin subtítulos"
    if activeUrl = "" then none = none + " (activo)"
    labels = [none]
    seen = {}
    for each s in subs
        name = Subs_langName(s.lang)
        if seen.DoesExist(name) then seen[name] = seen[name] + 1 else seen[name] = 1
        number = 0
        if totals[name] > 1 then number = seen[name]
        label = Subs_label(s, number)
        if s.url = activeUrl then label = label + " (activo)"
        labels.Push(label)
    end for
    return labels
end function

' Shifts every cue of an SRT by offsetMs (negative = earlier), clamping at 0. The Roku has no
' subtitle delay, so sync works by loading a shifted copy. Keeps line endings and cue text as is.
function Subs_shift(text as string, offsetMs as integer) as string
    timeRe = CreateObject("roRegex", "^(\d{1,2}):(\d{2}):(\d{2})[,.](\d{3}) --> (\d{1,2}):(\d{2}):(\d{2})[,.](\d{3})([\s\S]*)$", "")
    lines = text.Split(Chr(10))
    out = []
    for each line in lines
        found = timeRe.Match(line)
        if found.Count() = 10
            startMs = Subs_ms(found[1], found[2], found[3], found[4]) + offsetMs
            endMs = Subs_ms(found[5], found[6], found[7], found[8]) + offsetMs
            line = Subs_time(startMs) + " --> " + Subs_time(endMs) + found[9]
        end if
        out.Push(line)
    end for
    return out.Join(Chr(10))
end function

function Subs_ms(h as string, mi as string, sec as string, ms as string) as integer
    return h.ToInt() * 3600000 + mi.ToInt() * 60000 + sec.ToInt() * 1000 + ms.ToInt()
end function

function Subs_time(ms as integer) as string
    if ms < 0 then ms = 0
    h = ms \ 3600000
    mi = (ms mod 3600000) \ 60000
    sec = (ms mod 60000) \ 1000
    return Right("0" + h.ToStr(), 2) + ":" + Right("0" + mi.ToStr(), 2) + ":" + Right("0" + sec.ToStr(), 2) + "," + Right("00" + (ms mod 1000).ToStr(), 3)
end function

' "+1,5 s" / "-2,0 s" (half-second steps).
function Subs_formatOffset(offsetMs as integer) as string
    sign = "+"
    if offsetMs < 0 then sign = "-"
    tenths = Abs(offsetMs) \ 100
    return sign + (tenths \ 10).ToStr() + "," + (tenths mod 10).ToStr() + " s"
end function

function Subs_tracks(subs as object) as object
    out = []
    for each s in subs
        out.Push({ "Language": s.lang, "TrackName": s.url, "Description": Subs_label(s) })
    end for
    return out
end function
