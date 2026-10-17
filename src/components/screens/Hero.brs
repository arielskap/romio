sub init()
    m.top.focusable = true
    m.background = m.top.findNode("background")
    m.logo = m.top.findNode("logo")
    m.name = m.top.findNode("name")
    m.badge = m.top.findNode("badge")
    m.badgeText = m.top.findNode("badgeText")
    m.ageBorder = m.top.findNode("ageBorder")
    m.ageFill = m.top.findNode("ageFill")
    m.ageText = m.top.findNode("ageText")
    m.factsText = m.top.findNode("factsText")
    m.barBg = m.top.findNode("barBg")
    m.barFill = m.top.findNode("barFill")
    m.progressText = m.top.findNode("progressText")
    m.description = m.top.findNode("description")
    m.director = m.top.findNode("director")
    m.info = m.top.findNode("info")
    m.row = m.top.findNode("row")
    m.row.observeField("action", "onRowAction")
    m.logoSource = ""
    m.logo.observeField("loadStatus", "onLogoStatus")
    m.top.observeField("focusedChild", "onFocus")
end sub

function field(d as object, key as string) as string
    v = d[key]
    if GetInterface(v, "ifString") <> invalid then return v
    return ""
end function

sub onData()
    d = m.top.data
    if d = invalid then return
    m.background.uri = Art_background(field(d, "id"), field(d, "background"))
    m.name.text = field(d, "name")
    logo = field(d, "logo")
    if logo <> m.logoSource
        m.logoSource = logo
        m.logo.width = 560
        m.logo.height = 150
        m.logo.translation = [80, 150]
        m.logo.uri = Art_resize(logo, 780)
    end if
    showName(logo = "" or m.logo.loadStatus = "failed")

    ' Facts line: IMDb badge, age badge, then year · runtime · genres.
    x = 0
    rating = field(d, "imdbRating")
    m.badge.visible = rating <> ""
    m.badgeText.visible = rating <> ""
    if rating <> ""
        m.badgeText.text = "IMDb " + rating
        m.badge.width = m.badgeText.boundingRect().width + 20
        x = m.badge.width + 12
    end if
    age = field(d, "certification")
    m.ageBorder.visible = age <> ""
    m.ageFill.visible = age <> ""
    m.ageText.visible = age <> ""
    if age <> ""
        m.ageText.text = age
        w = m.ageText.boundingRect().width + 20
        m.ageBorder.translation = [x, 0]
        m.ageBorder.width = w
        m.ageFill.translation = [x + 2, 2]
        m.ageFill.width = w - 4
        m.ageText.translation = [x + 10, 4]
        x = x + w + 16
    end if
    parts = []
    for each key in ["year", "runtime", "genres"]
        if field(d, key) <> "" then parts.Push(field(d, key))
    end for
    m.factsText.translation = [x, 4]
    m.factsText.text = parts.Join("  ·  ")

    progress = 0
    if d.progress <> invalid then progress = d.progress
    m.barBg.visible = progress > 0
    m.barFill.visible = progress > 0
    m.progressText.translation = [80, 362]
    if progress > 0
        m.barFill.width = Int(220 * progress)
        m.progressText.translation = [316, 362]
    end if
    m.progressText.text = field(d, "progressText")
    ' The director line goes right under the description; two description lines leave room for it above the buttons.
    director = field(d, "director")
    m.description.maxLines = 3
    m.director.text = ""
    if director <> ""
        m.description.maxLines = 2
        m.director.text = "Dirección: " + director
    end if
    m.description.text = field(d, "description")
    m.director.translation = [80, 400 + m.description.boundingRect().height + 8]
end sub

sub onDimmed()
    m.info.visible = not m.top.dimmed
    if m.top.dimmed then m.top.opacity = 0.35 else m.top.opacity = 1
end sub

sub onLogoStatus()
    if m.logo.loadStatus = "failed" then showName(true)
    if m.logo.loadStatus = "ready"
        fitLogo()
        showName(false)
    end if
end sub

' scaleToFit centers the image in its box: shrink the box to the image so the logo sits left and bottom-aligned.
sub fitLogo()
    bw = m.logo.bitmapWidth
    bh = m.logo.bitmapHeight
    if bw <= 0 or bh <= 0 then return
    scale = 560 / bw
    if 150 / bh < scale then scale = 150 / bh
    m.logo.width = Int(bw * scale)
    m.logo.height = Int(bh * scale)
    m.logo.translation = [80, 300 - m.logo.height]
end sub

sub showName(on as boolean)
    m.name.visible = on
    m.logo.visible = not on
end sub

' buttons: [{ id, label, icon }], drawn by the ButtonRow.
sub buildButtons()
    m.row.buttons = m.top.buttons
end sub

sub onRowAction()
    m.top.action = m.row.action
end sub

' Screens focus the hero; its buttons take the keys.
sub onFocus()
    if m.top.hasFocus() then m.row.setFocus(true)
end sub
