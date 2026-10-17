sub init()
    m.title = m.top.findNode("title")
    m.message = m.top.findNode("message")
    m.card = m.top.findNode("card")
    m.cardItem = m.top.findNode("cardItem")
    m.ring = m.top.findNode("ring")
    m.tabs = m.top.findNode("tabs")
    m.list = m.top.findNode("list")
    m.streams = []
    m.zone = ""
    m.list.observeField("itemSelected", "onSelected")
    m.tabs.observeField("chosen", "onTabChosen")
    m.top.observeField("active", "onActive")
end sub

sub onActive()
    if m.streams.Count() > 0
        focusZone(m.zone)
        return
    end if
    p = m.top.params
    m.title.text = p.label
    Ui_parkFocus(m.top)
    ' Autoplay hands over the sources it already ranked, with a notice of why it stopped.
    if type(p.streams) = "roArray" and p.streams.Count() > 0
        showStreams(p.streams)
        return
    end if
    m.message.text = "Buscando fuentes…"
    m.task = Ui_runTask("streams", { addons: m.global.session.addons, type: p.meta.type, videoId: p.videoId, year: p.meta.year, resuming: isTrue(p.resuming) }, "onStreams")
end sub

sub onStreams(evt as object)
    r = evt.getData()
    if not r.ok
        m.message.text = r.error
        return
    end if
    showStreams(r.streams)
end sub

sub showStreams(streams as object)
    m.streams = streams
    p = m.top.params
    if Sources_str(p.notice) <> ""
        m.message.color = "0xF5C518FF"
        m.message.text = p.notice
    else
        m.message.text = streams.Count().ToStr() + " fuentes"
    end if
    m.recommended = Sources_recommended(streams)
    node = CreateObject("roSGNode", "ContentNode")
    node.addFields({ stream: streams[m.recommended] })
    m.cardItem.itemContent = node
    m.card.visible = true
    m.tabList = Sources_tabs(streams)
    labels = []
    for each t in m.tabList
        labels.Push(t.label)
    end for
    m.tabs.items = labels
    m.tabs.selected = 0
    m.tabs.visible = true
    showTab(0)
    focusZone("card")
end sub

sub showTab(index as integer)
    root = CreateObject("roSGNode", "ContentNode")
    for each i in m.tabList[index].indices
        c = root.createChild("ContentNode")
        c.addFields({ stream: m.streams[i], streamIndex: i })
    end for
    m.list.content = root
end sub

sub onTabChosen()
    index = m.tabs.chosen
    m.tabs.selected = index
    showTab(index)
    m.list.jumpToItem = 0
    focusZone("list")
end sub

sub focusZone(zone as string)
    m.zone = zone
    m.ring.visible = zone = "card"
    m.list.drawFocusFeedback = zone = "list"
    if zone = "tabs"
        m.tabs.setFocus(true)
    else if zone = "list"
        m.list.setFocus(true)
    else
        Ui_parkFocus(m.top)
    end if
end sub

sub onSelected()
    c = m.list.content.getChild(m.list.itemSelected)
    if c <> invalid then play(c.streamIndex)
end sub

' A source picked by hand plays alone: no autoplay to other sources.
sub play(index as integer)
    p = m.top.params
    m.top.navigate = { action: "push", screen: "PlayerScreen", params: { meta: p.meta, videoId: p.videoId, label: p.label, streams: m.streams, index: index, fromStart: isTrue(p.fromStart) } }
end sub

' Params may lack a flag: comparing invalid to a boolean crashes.
function isTrue(x as dynamic) as boolean
    return GetInterface(x, "ifBoolean") <> invalid and x
end function

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or m.streams.Count() = 0 then return false
    if key = "OK" and m.zone = "card"
        play(m.recommended)
        return true
    end if
    if key = "down"
        if m.zone = "card" then focusZone("tabs") else if m.zone = "tabs" then focusZone("list")
        return true
    end if
    if key = "up"
        if m.zone = "list" then focusZone("tabs") else if m.zone = "tabs" then focusZone("card")
        return true
    end if
    return false
end function
