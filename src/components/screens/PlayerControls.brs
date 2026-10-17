sub init()
    m.top.focusable = true
    m.topGroup = m.top.findNode("top")
    m.title = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
    m.quality = m.top.findNode("quality")
    m.endsAt = m.top.findNode("endsAt")
    m.fill = m.top.findNode("fill")
    m.elapsed = m.top.findNode("elapsed")
    m.remaining = m.top.findNode("remaining")
    m.row = m.top.findNode("row")
    m.row.observeField("action", "onRowAction")
    m.top.observeField("focusedChild", "onFocus")
end sub

sub onInfo()
    info = m.top.info
    m.title.text = text(info, "title")
    m.subtitle.text = text(info, "subtitle")
    m.quality.text = text(info, "quality")
    m.endsAt.text = text(info, "endsAt")
end sub

function text(info as object, key as string) as string
    if info = invalid then return ""
    v = info[key]
    if GetInterface(v, "ifString") <> invalid then return v
    return ""
end function

sub renderBar()
    duration = m.top.durationSec
    position = m.top.positionSec
    if position < 0 then position = 0
    if duration > 0 and position > duration then position = duration
    w = 0
    if duration > 0 then w = Int(1760 * position / duration)
    m.fill.width = w
    m.fill.visible = w > 0
    m.elapsed.text = Format_time(Int(position * 1000))
    m.remaining.text = ""
    if duration > 0 then m.remaining.text = "-" + Format_time(Int((duration - position) * 1000))
end sub

sub onButtons()
    m.row.buttons = m.top.buttons
end sub

sub onFocusIndex()
    m.row.focusIndex = m.top.focusIndex
end sub

sub onBarOnly()
    m.topGroup.visible = not m.top.barOnly
    m.row.visible = not m.top.barOnly
end sub

sub onRowAction()
    m.top.action = m.row.action
end sub

sub onFocus()
    if m.top.hasFocus() then m.row.setFocus(true)
end sub
