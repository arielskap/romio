sub init()
    m.photo = m.top.findNode("photo")
    m.name = m.top.findNode("name")
    m.character = m.top.findNode("character")
end sub

sub onContent()
    c = m.top.itemContent
    m.photo.uri = c.HDPosterUrl
    m.name.text = c.title
    character = ""
    if c.character <> invalid then character = c.character
    m.character.text = character
end sub
