' Request builders and response parsers for api.strem.io.

' JSON payload keys that are camelCase must be quoted: unquoted AA literal keys are lowercased by FormatJson.
function Stremio_request(method as string, payload as object) as object
    return { method: "POST", url: "https://api.strem.io/api/" + method, body: FormatJson(payload), timeoutMs: 15000 }
end function

function Stremio_loginRequest(email as string, password as string) as object
    return Stremio_request("login", { type: "Login", email: email, password: password, facts: {} })
end function

function Stremio_addonsRequest(authKey as string) as object
    return Stremio_request("addonCollectionGet", { type: "AddonCollectionGet", "authKey": authKey, update: true })
end function

function Stremio_libraryRequest(authKey as string) as object
    return Stremio_request("datastoreGet", { "authKey": authKey, collection: "libraryItem", ids: [], all: true })
end function

function Stremio_libraryItemRequest(authKey as string, id as string) as object
    return Stremio_request("datastoreGet", { "authKey": authKey, collection: "libraryItem", ids: [id], all: false })
end function

function Stremio_putLibraryRequest(authKey as string, items as object) as object
    return Stremio_request("datastorePut", { "authKey": authKey, collection: "libraryItem", changes: items })
end function

function Stremio_parse(resp as object) as object
    out = { ok: false, result: invalid, authError: false, wrongPassword: false, error: "" }
    data = resp.json
    if type(data) = "roAssociativeArray" and type(data.error) = "roAssociativeArray"
        e = data.error
        code = -1
        if GetInterface(e.code, "ifInt") <> invalid then code = e.code
        if code = 1
            out.authError = true
            out.error = "Tu sesión de Stremio venció. Volvé a iniciar sesión."
        else if (GetInterface(e.wrongPass, "ifBoolean") <> invalid and e.wrongPass) or code = 3
            out.wrongPassword = true
            out.error = "Mail o contraseña incorrectos."
        else if GetInterface(e.message, "ifString") <> invalid and e.message <> ""
            out.error = "Stremio respondió: " + e.message
        else
            out.error = "Stremio respondió con un error."
        end if
        return out
    end if
    if not resp.ok or type(data) <> "roAssociativeArray"
        out.error = "No se pudo conectar con Stremio (" + resp.error + ")."
        return out
    end if
    out.ok = true
    out.result = data.result
    return out
end function

function Stremio_parseLogin(resp as object) as object
    p = Stremio_parse(resp)
    authKey = ""
    if p.ok and type(p.result) = "roAssociativeArray" and GetInterface(p.result.authKey, "ifString") <> invalid then authKey = p.result.authKey
    return { ok: p.ok and authKey <> "", authKey: authKey, wrongPassword: p.wrongPassword, error: p.error }
end function

function Stremio_parseAddons(resp as object) as object
    p = Stremio_parse(resp)
    addons = []
    if p.ok and type(p.result) = "roAssociativeArray" and type(p.result.addons) = "roArray" then addons = p.result.addons
    return { ok: p.ok, authError: p.authError, addons: addons, error: p.error }
end function

function Stremio_parseLibrary(resp as object) as object
    p = Stremio_parse(resp)
    items = []
    if p.ok and type(p.result) = "roArray" then items = p.result
    return { ok: p.ok, authError: p.authError, items: items, error: p.error }
end function
