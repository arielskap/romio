sub init()
    m.top.focusable = true
    m.brand = m.top.findNode("brand")
    m.appName = m.top.findNode("appName")
    m.appName.text = UCase(Ui_appName())
    m.tabs = m.top.findNode("tabs")
    m.focusIndex = 0
    m.top.observeField("focusedChild", "render")
end sub

sub build()
    m.brand.visible = m.top.showBrand
    x = 0
    if m.top.showBrand then x = 72 + m.appName.boundingRect().width + 64
    m.tabs.removeChildrenIndex(m.tabs.getChildCount(), 0)
    ' showBrand can be set before items (XML attributes apply first): nothing to build yet.
    items = m.top.items
    if items = invalid then items = []
    for each text in items
        tabNode = m.tabs.createChild("Group")
        tabNode.translation = [x, 0]
        pill = tabNode.createChild("Rectangle")
        label = tabNode.createChild("Label")
        label.font = "font:MediumSystemFont"
        label.text = text
        label.translation = [20, 12]
        w = label.boundingRect().width + 40
            pill.width = w
        pill.height = 56
        pill.color = "0xFFFFFF26"
        line = tabNode.createChild("Rectangle")
        line.translation = [20, 60]
        line.width = w - 40
        line.height = 4
        line.color = "0xF2613FFF"
        x = x + w + 8
    end for
    render()
end sub

' Entering the bar lands on the active tab.
sub onSelected()
    m.focusIndex = m.top.selected
    render()
end sub

sub render()
    focused = m.top.hasFocus()
    for i = 0 to m.tabs.getChildCount() - 1
        tabNode = m.tabs.getChild(i)
        isFocus = focused and i = m.focusIndex
        isSelected = i = m.top.selected
        ' findNode searches from the component, not from tabNode, so children go by index: pill, label, line.
        tabNode.getChild(0).visible = isFocus
        tabNode.getChild(2).visible = isSelected
        label = tabNode.getChild(1)
        if isFocus or isSelected then label.color = "0xFFFFFFFF" else label.color = "0xAAAAAAFF"
    end for
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or not m.top.hasFocus() then return false
    count = m.tabs.getChildCount()
    if key = "left" and m.focusIndex > 0
        m.focusIndex = m.focusIndex - 1
        render()
        return true
    end if
    if key = "right" and m.focusIndex < count - 1
        m.focusIndex = m.focusIndex + 1
        render()
        return true
    end if
    if key = "left" or key = "right" then return true
    if key = "OK"
        m.top.chosen = m.focusIndex
        return true
    end if
    return false
end function
