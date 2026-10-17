' Real-Debrid: key discovery, downloads lookup and HLS transcoding.

function RD_api(path as string) as string
    return "https://api.real-debrid.com/rest/1.0" + path
end function

function RD_keyFromAddons(addons as object) as string
    for each a in addons
        key = Addons_match("realdebrid=([A-Za-z0-9]+)", Addons_str(a.base))
        if key <> "" then return key
    end for
    return ""
end function

function RD_downloadsRequest(key as string) as object
    return { method: "GET", url: RD_api("/downloads?limit=50"), headers: { "Authorization": "Bearer " + key }, timeoutMs: 15000 }
end function

function RD_transcodeRequest(key as string, id as string) as object
    return { method: "GET", url: RD_api("/streaming/transcode/" + id), headers: { "Authorization": "Bearer " + key }, timeoutMs: 15000 }
end function

' Downloads come newest first, so the first match is the one the addon just added.
function RD_findDownload(resp as object, filename as string) as dynamic
    if not resp.ok then return invalid
    for each d in Addons_arr(resp.json)
        if type(d) = "roAssociativeArray" and Addons_str(d.filename) = filename and Addons_str(d.id) <> ""
            return { id: d.id, download: Addons_str(d.download) }
        end if
    end for
    return invalid
end function

function RD_isKeyProblem(resp as object) as boolean
    return resp.code = 401
end function

function RD_error(resp as object) as string
    if resp.code = 401 then return "La clave de Real-Debrid no es válida."
    if resp.code = 403 then return "Tu cuenta de Real-Debrid venció o no tiene premium."
    if resp.code <= 0 then return "No se pudo conectar con Real-Debrid (" + resp.error + ")."
    return "Real-Debrid respondió con un error (" + resp.code.ToStr() + ")."
end function

function RD_parseTranscode(resp as object) as object
    if not resp.ok then return { ok: false, url: "", error: RD_error(resp), keyProblem: RD_isKeyProblem(resp) }
    data = resp.json
    if type(data) = "roAssociativeArray" and type(data.apple) = "roAssociativeArray" and Addons_str(data.apple.high) <> ""
        return { ok: true, url: data.apple.high, error: "", keyProblem: false }
    end if
    return { ok: false, url: "", error: "Real-Debrid no ofreció una versión convertida de este archivo.", keyProblem: false }
end function
