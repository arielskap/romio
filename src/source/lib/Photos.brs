' Optional photos for the loading screens, added with `npm run photos` into a git-ignored folder.
' Without photos, Photos_next returns "" and the screens look as usual.

' One image name from `files` (ListDir output) chosen by `roll` in [0, 1), never `last` while there are others.
function Photos_pick(files as object, last as string, roll as float) as string
    candidates = []
    for each f in files
        name = LCase(f)
        if name.EndsWith(".jpg") or name.EndsWith(".jpeg") or name.EndsWith(".png") then candidates.Push(f)
    end for
    if candidates.Count() > 1
        others = []
        for each f in candidates
            if f <> last then others.Push(f)
        end for
        candidates = others
    end if
    if candidates.Count() = 0 then return ""
    return candidates[Int(roll * candidates.Count())]
end function

' Picks the next photo and remembers it, so opening the app twice shows two different ones.
function Photos_next() as string
    dir = "pkg:/images/photos"
    name = Photos_pick(ListDir(dir), Storage_get("lastPhoto"), Rnd(0))
    if name = "" then return ""
    Storage_set("lastPhoto", name)
    return dir + "/" + name
end function
