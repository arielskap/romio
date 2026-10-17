sub init()
    m.global.addFields({ session: {} })
    m.stack = m.top.findNode("stack")
    m.bootLabel = m.top.findNode("boot")
    m.skeleton = m.top.findNode("skeleton")
    m.intro = m.top.findNode("intro")
    m.top.findNode("introName").text = UCase(Ui_appName())
    m.bootFailed = false
    m.animDone = false
    anim = m.top.findNode("introAnim")
    showIntroPhoto(anim)
    anim.observeField("state", "onIntroState")
    anim.control = "start"
    boot()
end sub

' With a photo the intro moves the logo to the right and stays longer, so the photo can be seen.
sub showIntroPhoto(anim as object)
    uri = Photos_next()
    if uri = "" then return
    photo = m.top.findNode("introPhoto")
    photo.uri = uri
    photo.visible = true
    m.top.findNode("introLogo").translation = [1170, 330]
    name = m.top.findNode("introName")
    name.translation = [880, 620]
    name.width = 820
    anim.duration = 3.5
end sub

sub onIntroState(evt as object)
    if evt.getData() <> "stopped" then return
    m.animDone = true
    advance()
end sub

' Never touches m.animDone, so a retry shows the skeleton instead of replaying the intro.
sub boot()
    m.bootFailed = false
    m.bootResult = invalid
    m.bootLabel.visible = false
    m.top.setFocus(true)
    m.task = Ui_runTask("boot", {}, "onBoot")
    advance()
end sub

sub onBoot(evt as object)
    m.bootResult = evt.getData()
    advance()
end sub

sub advance()
    introStep = Intro_step(m.animDone, m.bootResult <> invalid)
    if introStep = "wait" then return
    m.intro.visible = false
    m.skeleton.visible = (introStep = "skeleton")
    if introStep = "go" then showBootResult(m.bootResult)
end sub

sub showBootResult(r as object)
    if r.ok
        m.global.session = { authKey: r.authKey, addons: r.addons, library: r.library, libraryLoaded: r.libraryLoaded, rdKey: r.rdKey }
        resetTo("HomeScreen", {})
    else if r.authError
        email = ""
        if GetInterface(r.lastEmail, "ifString") <> invalid then email = r.lastEmail
        resetTo("LoginScreen", { message: r.error, email: email })
    else
        m.bootLabel.text = r.error + Chr(10) + "Apretá OK para reintentar."
        m.bootLabel.visible = true
        m.bootFailed = true
    end if
end sub

function currentScreen() as dynamic
    n = m.stack.getChildCount()
    if n = 0 then return invalid
    return m.stack.getChild(n - 1)
end function

sub push(name as string, params as object)
    top = currentScreen()
    if top <> invalid then top.visible = false
    s = CreateObject("roSGNode", name)
    s.params = params
    s.observeField("navigate", "onNavigate")
    m.stack.appendChild(s)
    s.active = true
end sub

sub resetTo(name as string, params as object)
    m.stack.removeChildrenIndex(m.stack.getChildCount(), 0)
    push(name, params)
end sub

sub pop()
    n = m.stack.getChildCount()
    if n <= 1 then return
    m.stack.removeChildIndex(n - 1)
    top = currentScreen()
    top.visible = true
    top.active = true
end sub

sub onNavigate(evt as object)
    nav = evt.getData()
    if nav.action = "push"
        push(nav.screen, nav.params)
    else if nav.action = "back"
        pop()
    else if nav.action = "replace"
        ' The screen below is not reactivated: the new one takes the top's place.
        n = m.stack.getChildCount()
        if n > 1 then m.stack.removeChildIndex(n - 1)
        ' dropBelow also removes a screen of that type left under it (a sources list for another episode).
        if nav.dropBelow <> invalid
            below = currentScreen()
            if below <> invalid and m.stack.getChildCount() > 1 and below.subtype() = nav.dropBelow then m.stack.removeChildIndex(m.stack.getChildCount() - 1)
        end if
        push(nav.screen, nav.params)
    else if nav.action = "boot"
        m.stack.removeChildrenIndex(m.stack.getChildCount(), 0)
        boot()
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "OK" and m.bootFailed
        boot()
        return true
    end if
    if key = "back" and m.stack.getChildCount() > 1
        pop()
        return true
    end if
    return false
end function
