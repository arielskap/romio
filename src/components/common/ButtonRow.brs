sub init()
    m.top.focusable = true
    m.row = m.top.findNode("row")
    m.ring = m.top.findNode("ring")
    m.buttonX = []
    m.buttonW = []
    m.top.observeField("focusedChild", "renderFocus")
end sub

' buttons: [{ id, label, icon }]. The primary one is white, so its icon must be dark (icon_play).
' A button without a label is a square icon button.
sub build()
    m.row.removeChildrenIndex(m.row.getChildCount(), 0)
    m.buttonX = []
    m.buttonW = []
    x = 0
    list = m.top.buttons
    if list = invalid then list = []
    for i = 0 to list.Count() - 1
        b = list[i]
        btn = m.row.createChild("Group")
        btn.translation = [x, 0]
        bg = btn.createChild("Rectangle")
        bg.height = 64
        primary = i = m.top.primaryIndex
        if primary then bg.color = "0xFFFFFFFF" else bg.color = "0xFFFFFF38"
        w = 64
        icon = invalid
        if b.icon <> ""
            icon = btn.createChild("Poster")
            icon.uri = b.icon
            icon.width = 40
            icon.height = 40
            icon.translation = [12, 12]
        end if
        if b.label <> ""
            labelX = 32
            if b.icon <> ""
                labelX = 76
                icon.translation = [24, 12]
            end if
            label = btn.createChild("Label")
            label.font = "font:MediumBoldSystemFont"
            label.text = b.label
            label.translation = [labelX, 14]
            if primary then label.color = "0x000000FF"
            w = label.boundingRect().width + labelX + 28
        end if
        bg.width = w
        m.buttonX.Push(x)
        m.buttonW.Push(w)
        x = x + w + 20
    end for
    if m.top.focusIndex >= list.Count() then m.top.focusIndex = list.Count() - 1
    if m.top.focusIndex < 0 then m.top.focusIndex = 0
    renderFocus()
end sub

sub onRelabel()
    r = m.top.relabel
    btn = m.row.getChild(r.index)
    ' The label is the button's last child (after the background and the icon).
    if btn <> invalid then btn.getChild(btn.getChildCount() - 1).text = r.label
end sub

sub renderFocus()
    m.ring.visible = m.top.hasFocus() and m.buttonX.Count() > 0
    if m.buttonX.Count() = 0 then return
    i = m.top.focusIndex
    if i < 0 or i >= m.buttonX.Count() then return
    m.ring.translation = [m.buttonX[i] - 8, -8]
    m.ring.width = m.buttonW[i] + 16
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or not m.top.hasFocus() then return false
    count = m.buttonX.Count()
    if key = "left" or key = "right"
        if key = "left" and m.top.focusIndex > 0 then m.top.focusIndex = m.top.focusIndex - 1
        if key = "right" and m.top.focusIndex < count - 1 then m.top.focusIndex = m.top.focusIndex + 1
        return true
    end if
    if key = "OK" and count > 0
        m.top.action = m.top.buttons[m.top.focusIndex].id
        return true
    end if
    return false
end function
