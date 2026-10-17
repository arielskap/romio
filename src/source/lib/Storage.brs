' Persistent key/value storage in the Roku registry.

function Storage_section() as object
    return CreateObject("roRegistrySection", "roku-stremio")
end function

function Storage_get(key as string) as string
    s = Storage_section()
    if s.Exists(key) then return s.Read(key)
    return ""
end function

' The registry holds 16 KB per app: a write past that fails, so failures are logged instead of lost silently.
function Storage_set(key as string, value as string) as boolean
    s = Storage_section()
    ok = s.Write(key, value) and s.Flush()
    if not ok then print "[Storage] could not save "; key; " ("; Len(value); " bytes)"
    return ok
end function

sub Storage_delete(key as string)
    s = Storage_section()
    ' Flush writes flash; skip it in the common case where there is nothing to delete.
    if not s.Exists(key) then return
    s.Delete(key)
    s.Flush()
end sub
