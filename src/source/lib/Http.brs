' Concurrent HTTP with per-request timeouts. Only call from a Task node.

function Http_fail(reason as string) as object
    return { ok: false, code: 0, json: invalid, error: reason }
end function

function Http_timeout(req as object) as integer
    if GetInterface(req.timeoutMs, "ifInt") <> invalid then return req.timeoutMs
    return 10000
end function

function Http_newTransfer(req as object, port as object) as object
    t = CreateObject("roUrlTransfer")
    t.SetUrl(req.url)
    t.SetCertificatesFile("common:/certs/ca-bundle.crt")
    t.InitClientCertificates()
    t.RetainBodyOnError(true)
    t.SetMessagePort(port)
    t.AddHeader("Accept", "application/json")
    if type(req.headers) = "roAssociativeArray"
        for each k in req.headers
            t.AddHeader(k, req.headers[k])
        end for
    end if
    return t
end function

' Parses only bodies that look like JSON, so HTML error pages don't log ParseJSON errors.
function Http_parseBody(body as string) as dynamic
    first = Left(body.Trim(), 1)
    if first = "{" or first = "[" then return ParseJson(body)
    return invalid
end function

' keepText: also return the raw body as `text` (subtitle files are not JSON).
function Http_toResponse(msg as object, keepText = false as boolean) as object
    code = msg.GetResponseCode()
    body = msg.GetString()
    if body = invalid then body = ""
    data = Http_parseBody(body)
    ok = code >= 200 and code < 300
    err = ""
    if not ok
        err = msg.GetFailureReason()
        if err = invalid or err = "" then err = "HTTP " + code.ToStr()
    end if
    response = { ok: ok, code: code, json: data, error: err }
    if keepText then response.text = body
    return response
end function

' Runs all requests at once and returns their responses in the same order.
function Http_all(reqs as object) as object
    port = CreateObject("roMessagePort")
    clock = CreateObject("roTimespan")
    pending = {}
    results = []
    for i = 0 to reqs.Count() - 1
        req = reqs[i]
        results.Push(invalid)
        t = Http_newTransfer(req, port)
        started = false
        if req.method = "POST"
            t.AddHeader("Content-Type", "application/json")
            started = t.AsyncPostFromString(req.body)
        else if req.method = "HEAD"
            started = t.AsyncHead()
        else
            started = t.AsyncGetToString()
        end if
        if started
            pending[t.GetIdentity().ToStr()] = { index: i, transfer: t, timeoutMs: Http_timeout(req), keepText: Addons_isTrue(req.keepText) }
        else
            results[i] = Http_fail("could not start request")
        end if
    end for
    while not pending.IsEmpty()
        msg = wait(250, port)
        if type(msg) = "roUrlEvent" and msg.GetInt() = 1
            key = msg.GetSourceIdentity().ToStr()
            p = pending[key]
            if p <> invalid
                results[p.index] = Http_toResponse(msg, p.keepText)
                pending.Delete(key)
            end if
        end if
        elapsed = clock.TotalMilliseconds()
        for each key in pending.Keys()
            p = pending[key]
            if elapsed >= p.timeoutMs
                p.transfer.AsyncCancel()
                results[p.index] = Http_fail("timeout")
                pending.Delete(key)
            end if
        end for
    end while
    return results
end function

function Http_request(req as object) as object
    return Http_all([req])[0]
end function

' Fetches a byte range as a hex string, "" on failure.
function Http_getHex(url as string, range as string, timeoutMs as integer) as string
    bytes = Http_getBytes(url, range, timeoutMs)
    if bytes = invalid then return ""
    return bytes.ToHexString()
end function

' Fetches a byte range (e.g. "0-262143") into an roByteArray, or invalid on failure.
' Bytes go through a tmp file because BrightScript strings can't hold binary data. Real-Debrid
' answers suffix ranges ("-N") with the start of the file, so only explicit ranges work.
function Http_getBytes(url as string, range as string, timeoutMs as integer) as dynamic
    port = CreateObject("roMessagePort")
    t = Http_newTransfer({ url: url, headers: { "Range": "bytes=" + range } }, port)
    path = "tmp:/sniff.bin"
    if not t.AsyncGetToFile(path) then return ""
    ' Only a "transfer complete" event (GetInt 1) means the file is fully written.
    clock = CreateObject("roTimespan")
    msg = invalid
    remaining = timeoutMs
    while msg = invalid and remaining > 0
        ev = wait(remaining, port)
        remaining = timeoutMs - clock.TotalMilliseconds()
        if type(ev) = "roUrlEvent" and ev.GetInt() = 1 then msg = ev
    end while
    if msg = invalid then t.AsyncCancel()
    bytes = CreateObject("roByteArray")
    ok = msg <> invalid and (msg.GetResponseCode() = 200 or msg.GetResponseCode() = 206) and bytes.ReadFile(path)
    ' Always cleaned up: tmp: is small and a partial download would linger otherwise.
    DeleteFile(path)
    if not ok then return invalid
    return bytes
end function
