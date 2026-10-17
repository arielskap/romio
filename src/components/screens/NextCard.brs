sub init()
    m.top.focusable = true
    m.thumb = m.top.findNode("thumb")
    m.name = m.top.findNode("name")
    m.row = m.top.findNode("row")
    m.row.observeField("action", "onRowAction")
    m.top.observeField("focusedChild", "onFocus")
end sub

sub onEpisode()
    ep = m.top.episode
    if ep = invalid then return
    m.thumb.uri = ep.thumbnail
    m.name.text = ep.title
end sub

' The countdown only changes the play button's text: the row is built once per card.
sub onSeconds()
    label = "Reproducir en " + m.top.seconds.ToStr()
    if m.row.buttons = invalid or m.row.buttons.Count() = 0
        m.row.buttons = [{ id: "play", label: label, icon: "pkg:/images/icon_play.png" }, { id: "dismiss", label: "Ver créditos", icon: "" }]
    else
        m.row.relabel = { index: 0, label: label }
    end if
end sub

sub onRowAction()
    m.top.action = m.row.action
end sub

sub onFocus()
    if m.top.hasFocus() then m.row.setFocus(true)
end sub
