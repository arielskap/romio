sub init()
    m.keyboard = m.top.findNode("keyboard")
    m.save = m.top.findNode("save")
    m.message = m.top.findNode("message")
    m.keyboard.domain = "alphanumeric"
    m.save.observeField("buttonSelected", "onSave")
    m.top.observeField("active", "onActive")
end sub

sub onActive()
    m.keyboard.setFocus(true)
end sub

sub onSave()
    key = m.keyboard.text.Trim()
    if key = ""
        m.message.text = "Pegá o escribí la clave para seguir."
        return
    end if
    Storage_set("rdKey", key)
    session = m.global.session
    session.rdKey = key
    m.global.session = session
    m.top.navigate = { action: "back" }
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    return Ui_keyboardNav(key, m.keyboard, m.save)
end function
