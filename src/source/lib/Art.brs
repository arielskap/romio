' Artwork URLs sized for the Roku: full-size originals cost memory and download time.

function Art_resize(url as string, width as integer) as string
    tmdb = "image.tmdb.org/t/p/original/"
    if url.Instr(tmdb) >= 0 then return url.Replace(tmdb, "image.tmdb.org/t/p/w" + width.ToStr() + "/")
    if url.Instr("images.metahub.space/") >= 0 then return url.Replace("/large/", "/medium/")
    return url
end function

' Background for an item, falling back to metahub's by IMDb id when the item has none.
function Art_background(id as string, background as string) as string
    if background <> "" then return Art_resize(background, 1280)
    if Left(id, 2) = "tt" then return "https://images.metahub.space/background/medium/" + id + "/img"
    return ""
end function
