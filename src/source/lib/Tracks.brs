' Audio tracks and subtitle style for the player's menus.

function Tracks_str(x as dynamic) as string
    if GetInterface(x, "ifString") <> invalid then return x
    return ""
end function

' Video reports ISO 639-2 codes ("spa"); some files carry 639-1 ("es").
function Tracks_languageName(code as string) as string
    names = {
        spa: "Español", es: "Español", eng: "Inglés", en: "Inglés", por: "Portugués", pt: "Portugués",
        ita: "Italiano", it: "Italiano", fra: "Francés", fre: "Francés", fr: "Francés",
        deu: "Alemán", ger: "Alemán", de: "Alemán", jpn: "Japonés", ja: "Japonés",
        kor: "Coreano", ko: "Coreano", rus: "Ruso", ru: "Ruso", hin: "Hindi", hi: "Hindi", tam: "Tamil", ta: "Tamil",
        tel: "Telugu", te: "Telugu", chi: "Chino", zho: "Chino", zh: "Chino", tur: "Turco", tr: "Turco", pol: "Polaco", pl: "Polaco"
    }
    c = LCase(code)
    if names.DoesExist(c) then return names[c]
    return UCase(code)
end function

' Menu items for Video.availableAudioTracks: { label, track, lang }.
function Tracks_audioItems(available as dynamic) as object
    items = []
    if type(available) <> "roArray" then return items
    for i = 0 to available.Count() - 1
        t = available[i]
        if type(t) = "roAssociativeArray"
            lang = Tracks_str(t.Language)
            name = Tracks_str(t.Name)
            ' Some files name tracks with internal ids ("#uniq:KIN(1)"): not worth showing.
            if Left(name, 1) = "#" then name = ""
            label = Tracks_languageName(lang)
            if name <> "" and name <> label
                if label = "" then label = name else label = label + " · " + name
            end if
            if label = "" then label = "Pista " + (i + 1).ToStr()
            items.Push({ label: label, track: Tracks_str(t.Track), lang: lang })
        end if
    end for
    return items
end function

' The exact track chosen survives reloads of the same file; the language carries the choice to other files.
function Tracks_pickAudio(available as dynamic, track as string, lang as string) as string
    items = Tracks_audioItems(available)
    for each item in items
        if item.track = track and track <> "" then return item.track
    end for
    for each item in items
        if item.lang = lang and lang <> "" then return item.track
    end for
    return ""
end function

' size: small|medium|large, background: none|semi|solid; anything else keeps the system setting.
function Tracks_captionStyle(size as string, background as string) as object
    sizes = { small: "Small", medium: "Medium", large: "Large" }
    opacities = { none: "Off", semi: "50%", solid: "100%" }
    style = { "Text/Size": "Default", "Background/Color": "Black", "Background/Opacity": "Default" }
    if sizes.DoesExist(size) then style["Text/Size"] = sizes[size]
    if opacities.DoesExist(background) then style["Background/Opacity"] = opacities[background]
    return style
end function

function Tracks_nextSize(size as string) as string
    if size = "small" then return "medium"
    if size = "medium" then return "large"
    if size = "large" then return "small"
    return "medium"
end function

function Tracks_nextBackground(background as string) as string
    if background = "none" then return "semi"
    if background = "semi" then return "solid"
    if background = "solid" then return "none"
    return "semi"
end function

function Tracks_sizeLabel(size as string) as string
    labels = { small: "Chico", medium: "Mediano", large: "Grande" }
    if labels.DoesExist(size) then return "Tamaño: " + labels[size]
    return "Tamaño: Normal"
end function

function Tracks_backgroundLabel(background as string) as string
    labels = { none: "Sin fondo", semi: "Semitransparente", solid: "Negro" }
    if labels.DoesExist(background) then return "Fondo: " + labels[background]
    return "Fondo: Normal"
end function
