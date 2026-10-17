sub init()
    m.keyboard = m.top.findNode("keyboard")
    m.actions = m.top.findNode("actions")
    m.stepLabel = m.top.findNode("step")
    m.stepCount = m.top.findNode("stepCount")
    m.dot2 = m.top.findNode("dot2")
    m.message = m.top.findNode("message")
    m.email = ""
    m.actions.observeField("action", "onAction")
    m.top.observeField("active", "onActive")
    showStep(0)
end sub

sub onActive()
    p = m.top.params
    if p <> invalid and p.message <> invalid then m.message.text = p.message
    ' The last email that logged in, still editable.
    if p <> invalid and GetInterface(p.email, "ifString") <> invalid and p.email <> "" and m.email = ""
        m.email = p.email
        showStep(0)
        return
    end if
    m.keyboard.setFocus(true)
end sub

sub showStep(index as integer)
    m.stepIndex = index
    m.keyboard.text = ""
    if index = 0
        m.stepCount.text = "Paso 1 de 2"
        m.dot2.color = "0xFFFFFF33"
        m.stepLabel.text = "Mail"
        m.keyboard.domain = "email"
        m.keyboard.textEditBox.secureMode = false
        m.keyboard.text = m.email
        setActions([{ id: "next", label: "Siguiente", icon: "pkg:/images/icon_arrow.png" }], 0)
    else
        m.stepCount.text = "Paso 2 de 2"
        m.dot2.color = "0xF2613FFF"
        m.stepLabel.text = "Contraseña de " + m.email
        m.keyboard.domain = "password"
        m.keyboard.textEditBox.secureMode = true
        setActions(passwordButtons(), 2)
    end if
    m.keyboard.setFocus(true)
end sub

' The eye button shows or hides the password, to check what was typed.
function passwordButtons() as object
    if m.keyboard.textEditBox.secureMode
        eye = { id: "eye", label: "Mostrar", icon: "pkg:/images/icon_eye.png" }
    else
        eye = { id: "eye", label: "Ocultar", icon: "pkg:/images/icon_eye_off.png" }
    end if
    return [{ id: "back", label: "Atrás", icon: "pkg:/images/icon_back.png" }, eye, { id: "next", label: "Iniciar sesión", icon: "pkg:/images/icon_arrow.png" }]
end function

' The forward button is the primary (white) one; the row ends where the keyboard does.
sub setActions(buttons as object, focusIndex as integer)
    m.actions.primaryIndex = buttons.Count() - 1
    m.actions.buttons = buttons
    m.actions.focusIndex = focusIndex
    keyboardRight = m.keyboard.translation[0] + m.keyboard.boundingRect().width
    m.actions.translation = [keyboardRight - m.actions.boundingRect().width, 760]
end sub

sub onAction()
    if m.actions.action = "back"
        m.message.text = ""
        showStep(0)
        return
    end if
    if m.actions.action = "eye"
        m.keyboard.textEditBox.secureMode = not m.keyboard.textEditBox.secureMode
        setActions(passwordButtons(), 1)
        return
    end if
    onNext()
end sub

sub onNext()
    value = m.keyboard.text.Trim()
    if value = ""
        m.message.text = "Completá el campo para seguir."
        return
    end if
    if m.stepIndex = 0
        m.email = value
        m.message.text = ""
        showStep(1)
        return
    end if
    m.message.text = "Iniciando sesión…"
    Ui_parkFocus(m.top)
    m.task = Ui_runTask("login", { email: m.email, password: value }, "onLogin")
end sub

sub onLogin(evt as object)
    r = evt.getData()
    m.task = invalid
    if r.ok
        m.top.navigate = { action: "boot" }
        return
    end if
    m.message.text = r.error
    if r.wrongPassword then showStep(0) else showStep(1)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if m.task <> invalid then return true
    if Ui_keyboardNav(key, m.keyboard, m.actions) then return true
    if key = "back" and m.stepIndex = 1
        showStep(0)
        return true
    end if
    return false
end function
