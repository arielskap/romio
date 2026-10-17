sub init()
    ' Tiles are recycled while scrolling, so the child lookups happen once.
    m.bg = m.top.findNode("bg")
    m.poster = m.top.findNode("poster")
    m.barBg = m.top.findNode("barBg")
    m.barFill = m.top.findNode("barFill")
    m.check = m.top.findNode("check")
    m.title = m.top.findNode("title")
    m.sub = m.top.findNode("sub")
end sub

sub onContent()
    c = m.top.itemContent
    w = 220
    h = 330
    if c.landscape <> invalid and c.landscape
        w = 330
        h = 186
    end if
    m.bg.width = w
    m.bg.height = h
    m.poster.width = w
    m.poster.height = h
    m.poster.loadWidth = w
    m.poster.loadHeight = h
    m.poster.uri = c.HDPosterUrl
    m.title.translation = [0, h + 8]
    m.title.width = w
    m.sub.translation = [0, h + 40]
    m.sub.width = w
    m.title.text = c.title
    subtitle = ""
    if c.subtitle <> invalid then subtitle = c.subtitle
    m.sub.text = subtitle

    progress = 0
    if c.progress <> invalid then progress = c.progress
    m.barBg.visible = progress > 0
    m.barFill.visible = progress > 0
    if progress > 0
        m.barBg.translation = [0, h - 6]
        m.barBg.width = w
        m.barFill.translation = [0, h - 6]
        m.barFill.width = Int(w * progress)
    end if
    m.check.visible = c.finished <> invalid and c.finished
    m.check.translation = [w - 48, 8]
end sub
