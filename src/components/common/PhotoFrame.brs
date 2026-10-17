sub init()
    m.boxW = 560
    m.boxH = 800
    m.border = 14
    m.tilt = m.top.findNode("tilt")
    m.frame = m.top.findNode("frame")
    m.photo = m.top.findNode("photo")
    m.photo.observeField("loadStatus", "onLoad")
end sub

sub onUri()
    m.tilt.visible = false
    m.photo.width = m.boxW
    m.photo.height = m.boxH
    m.photo.uri = m.top.uri
end sub

' The frame follows the photo's own shape: portrait and landscape photos both fit the box whole.
sub onLoad()
    if m.photo.loadStatus <> "ready" then return
    bw = m.photo.bitmapWidth
    bh = m.photo.bitmapHeight
    if bw <= 0 or bh <= 0 then return
    s = m.boxW / bw
    if m.boxH / bh < s then s = m.boxH / bh
    w = Int(bw * s)
    h = Int(bh * s)
    x = Int((m.boxW - w) / 2)
    y = Int((m.boxH - h) / 2)
    m.photo.width = w
    m.photo.height = h
    m.photo.translation = [x, y]
    m.frame.width = w + 2 * m.border
    m.frame.height = h + 2 * m.border
    m.frame.translation = [x - m.border, y - m.border]
    m.tilt.visible = true
end sub
