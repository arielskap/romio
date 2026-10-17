' Texts, colors and tabs for the sources screen, from the fields Addons_parseStreams and Addons_rankStreams add.

function Sources_str(x as dynamic) as string
    if GetInterface(x, "ifString") <> invalid then return x
    return ""
end function

function Sources_qualityText(s as object) as string
    q = Sources_str(s.quality)
    if q = "2160p" or q = "4k" or q = "4320p" then return "4K"
    if q = "" then return "?"
    return q
end function

' Tabs in a fixed order, each with the indices of its streams in the ranked list; empty tabs are left out.
function Sources_tabs(streams as object) as object
    names = ["1080p", "720p", "4K", "Otras"]
    indices = [[], [], [], []]
    for i = 0 to streams.Count() - 1
        q = Sources_qualityText(streams[i])
        slot = 3
        if q = "1080p" then slot = 0
        if q = "720p" then slot = 1
        if q = "4K" then slot = 2
        indices[slot].Push(i)
    end for
    tabs = []
    for t = 0 to 3
        if indices[t].Count() > 0 then tabs.Push({ label: names[t] + " (" + indices[t].Count().ToStr() + ")", indices: indices[t] })
    end for
    return tabs
end function

function Sources_phrase(s as object) as string
    note = Sources_str(s.note)
    if note <> "" then return note
    if Sources_str(s.compat) = "direct" then return "Directa — arranca al toque y adelantás sin cortes"
    return "Convertida — tarda en arrancar, adelantar puede trabarse"
end function

function Sources_color(s as object) as string
    if Sources_str(s.note) <> "" then return "0xAAAAAAFF"
    if Sources_str(s.compat) = "direct" then return "0x46D369FF"
    return "0xF5C518FF"
end function

' Languages, size, HDR, cache and addon, each shown as a pill.
function Sources_chips(s as object) as object
    chips = []
    langs = s.langs
    if type(langs) = "roArray" and langs.Count() > 0
        if langs.Count() = 1
            chips.Push(langs[0])
        else if langs.Count() = 2
            chips.Push(langs[0] + " + " + langs[1])
        else
            chips.Push(langs[0] + " + " + (langs.Count() - 1).ToStr() + " idiomas")
        end if
    end if
    if Sources_str(s.size) <> "" then chips.Push(s.size)
    if Sources_str(s.hdr) <> "" then chips.Push(s.hdr)
    if GetInterface(s.cached, "ifBoolean") <> invalid and s.cached then chips.Push("Real-Debrid listo")
    addon = Sources_str(s.addon)
    if addon <> "" then chips.Push(addon.Split(" ")[0])
    return chips
end function

' The first source not shown gray: after autoplay gave up, the ones it tried are marked and skipped here.
function Sources_recommended(streams as object) as integer
    for i = 0 to streams.Count() - 1
        if Sources_str(streams[i].note) = "" then return i
    end for
    return 0
end function
