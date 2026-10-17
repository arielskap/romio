sub init()
    m.keyboard = m.top.findNode("keyboard")
    m.go = m.top.findNode("go")
    m.message = m.top.findNode("message")
    m.results = m.top.findNode("results")
    m.go.observeField("buttonSelected", "onGo")
    m.results.observeField("rowItemSelected", "onSelected")
    m.top.observeField("active", "onActive")
end sub

sub onActive()
    if m.results.visible then m.results.setFocus(true) else m.keyboard.setFocus(true)
end sub

sub onGo()
    query = m.keyboard.text.Trim()
    if query = ""
        m.message.text = "Escribí qué querés buscar."
        return
    end if
    m.message.text = "Buscando “" + query + "”…"
    m.task = Ui_runTask("search", { addons: m.global.session.addons, query: query }, "onResults")
end sub

sub onResults(evt as object)
    r = evt.getData()
    if not r.ok or r.metas.Count() = 0
        m.results.visible = false
        if r.ok then m.message.text = "No encontré nada." else m.message.text = r.error
        return
    end if
    root = CreateObject("roSGNode", "ContentNode")
    row = root.createChild("ContentNode")
    for each meta in r.metas
        Ui_fillItem(row.createChild("ContentNode"), meta, meta.releaseInfo)
    end for
    m.results.content = root
    m.results.visible = true
    m.message.text = r.metas.Count().ToStr() + " resultados"
    m.results.setFocus(true)
end sub

sub onSelected()
    sel = m.results.rowItemSelected
    item = m.results.content.getChild(0).getChild(sel[1])
    if item = invalid then return
    m.top.navigate = Ui_detailNav(item)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if Ui_keyboardNav(key, m.keyboard, m.go) then return true
    if key = "down" and m.go.hasFocus() and m.results.visible
        m.results.setFocus(true)
        return true
    end if
    if key = "up" and m.results.hasFocus()
        m.go.setFocus(true)
        return true
    end if
    return false
end function
