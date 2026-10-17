sub init()
    m.shapes = m.top.findNode("shapes")
    m.pulse = m.top.findNode("pulse")
    m.top.observeField("visible", "onVisible")
end sub

' Each layout is a list of [x, y, width, height] in 1920x1080 coordinates.
function layoutRects(layout as string) as object
    ' "hero" is the upper half of "home", for screens whose rows draw their own grey tiles.
    if layout = "hero" then return [[80, 150, 560, 150], [80, 320, 760, 28], [80, 400, 620, 28], [80, 440, 520, 28], [80, 520, 240, 64], [340, 520, 240, 64]]
    if layout = "home"
        rects = [[80, 190, 560, 120], [80, 340, 760, 28], [80, 384, 620, 28], [80, 450, 220, 64], [320, 450, 220, 64], [80, 700, 300, 28]]
        for i = 0 to 4
            rects.Push([80 + i * 354, 750, 330, 186])
        end for
        return rects
    end if
    return []
end function

sub onLayout()
    m.shapes.removeChildrenIndex(m.shapes.getChildCount(), 0)
    for each r in layoutRects(m.top.layout)
        rect = m.shapes.createChild("Rectangle")
        rect.translation = [r[0], r[1]]
        rect.width = r[2]
        rect.height = r[3]
        rect.color = "0x1C1C22FF"
    end for
    onVisible()
end sub

sub onVisible()
    if m.top.visible then m.pulse.control = "start" else m.pulse.control = "stop"
end sub
