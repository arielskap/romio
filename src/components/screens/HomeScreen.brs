' Home: nav bar, featured title (hero) and rows. Inicio/Películas/Series rebuild the rows in place.
sub init()
    m.nav = m.top.findNode("nav")
    m.hero = m.top.findNode("hero")
    m.skeleton = m.top.findNode("skeleton")
    m.rows = m.top.findNode("rows")
    m.myList = m.top.findNode("myList")
    m.message = m.top.findNode("message")
    m.nav.items = ["Inicio", "Películas", "Series", "Mi lista", "Buscar"]
    m.kind = ""
    m.buildCount = 0
    m.built = false
    m.lastFocus = invalid
    m.rows.observeField("rowItemSelected", "onItemSelected")
    ' itemFocused is the row index and only changes on vertical moves (rowItemFocused fires on every poster).
    m.rows.observeField("itemFocused", "onItemFocused")
    m.rows.observeField("focusedChild", "layoutRows")
    m.nav.observeField("chosen", "onNavChosen")
    m.hero.observeField("action", "onHeroAction")
    m.myList.observeField("selectedItem", "onMyListSelected")
    m.top.observeField("active", "onActive")
end sub

sub onActive()
    if not m.built
        build("")
    else
        ' refreshContinue rebuilds the first row, which would reset the focused card.
        focused = m.rows.rowItemFocused
        hadContinue = hasContinueRow()
        focusedId = ""
        if hadContinue and focused <> invalid and focused.Count() = 2 and focused[0] = 0
            card = m.rowsRoot.getChild(0).getChild(focused[1])
            if card <> invalid then focusedId = card.metaId
        end if
        refreshContinue()
        if focused <> invalid and focused.Count() = 2
            target = Rows_shiftFocus(focused, hadContinue, hasContinueRow(), focusedId, continueIds())
            if target[0] < m.rowsRoot.getChildCount() then m.rows.jumpToRowItem = target
        end if
        ' The hero must follow what was just watched: an old episode there would rewind progress.
        if m.heroSource <> invalid and m.heroSource.kind = "library"
            item = Library_heroItem(continueItems(), m.kind)
            if item <> invalid then setHeroFromLibrary(item)
        end if
    end if
    if m.lastFocus <> invalid and m.lastFocus.visible then m.lastFocus.setFocus(true) else focusDefault()
end sub

' Focused rows slide up over the dimmed hero, so the focused row and its titles stay on screen.
' Runs whenever the rows gain or lose focus.
sub layoutRows()
    if m.rows.hasFocus()
        m.rows.translation = [80, 150]
        m.hero.dimmed = true
    else
        m.rows.translation = [80, 655]
        m.hero.dimmed = false
    end if
end sub

sub focusDefault()
    if m.hero.visible
        m.hero.setFocus(true)
    else if m.rowsRoot.getChildCount() > 0
        m.rows.setFocus(true)
    else
        m.nav.setFocus(true)
    end if
end sub

sub build(kind as string)
    m.built = true
    m.kind = kind
    m.myList.visible = false
    m.rows.visible = true
    m.buildCount = m.buildCount + 1
    m.rowsRoot = CreateObject("roSGNode", "ContentNode")
    m.catalogs = {}
    m.tasks = {}
    m.message.text = ""
    refreshContinue()
    i = 0
    for each cat in Addons_homeCatalogs(m.global.session.addons)
        if kind = "" or cat.type = kind
            row = m.rowsRoot.createChild("ContentNode")
            ' Unique per build, so answers for rows of a previous filter are ignored.
            row.id = "b" + m.buildCount.ToStr() + "c" + i.ToStr()
            row.title = cat.title
            Ui_placeholder(row, 6)
            m.catalogs[row.id] = { cat: cat, state: "idle" }
            i = i + 1
        end if
    end for
    applyRowSizes()
    m.rows.content = m.rowsRoot
    if m.rowsRoot.getChildCount() = 0 then m.message.text = "Tu cuenta no tiene catálogos de este tipo."

    m.heroSource = invalid
    m.hero.visible = false
    m.skeleton.visible = true
    item = Library_heroItem(continueItems(), kind)
    if item <> invalid then setHeroFromLibrary(item)
    ' Nothing to feature and no catalog that could provide one: no endless placeholder.
    if item = invalid and m.rowsRoot.getChildCount() = 0 then m.skeleton.visible = false
    loadAround(0)
end sub

function continueItems() as object
    out = []
    for each it in Library_continueWatching(m.global.session.library)
        if m.kind = "" or it.type = m.kind then out.Push(it)
    end for
    return out
end function

' The titles in "Continuar viendo", in order.
function continueIds() as object
    ids = []
    if not hasContinueRow() then return ids
    row = m.rowsRoot.getChild(0)
    for i = 0 to row.getChildCount() - 1
        ids.Push(row.getChild(i).metaId)
    end for
    return ids
end function

function hasContinueRow() as boolean
    return m.rowsRoot.getChildCount() > 0 and m.rowsRoot.getChild(0).id = "continue"
end function

' "Continuar viendo" uses landscape cards; every other row uses posters.
sub applyRowSizes()
    if hasContinueRow()
        m.rows.rowItemSize = [[330, 260], [220, 400]]
        m.rows.rowHeights = [340, 460]
    else
        m.rows.rowItemSize = [[220, 400]]
        m.rows.rowHeights = [460]
    end if
end sub

sub refreshContinue()
    items = continueItems()
    existing = invalid
    if m.rowsRoot.getChildCount() > 0 and m.rowsRoot.getChild(0).id = "continue" then existing = m.rowsRoot.getChild(0)
    if items.Count() = 0
        if existing <> invalid then m.rowsRoot.removeChild(existing)
        applyRowSizes()
        return
    end if
    if existing = invalid
        existing = CreateObject("roSGNode", "ContentNode")
        existing.id = "continue"
        existing.title = "Continuar viendo"
        m.rowsRoot.insertChild(existing, 0)
        m.message.text = ""
    end if
    existing.removeChildrenIndex(existing.getChildCount(), 0)
    for each it in items
        Ui_fillLibraryItem(existing.createChild("ContentNode"), it, true)
    end for
    applyRowSizes()
end sub

sub setHeroFromLibrary(item as object)
    m.heroSource = { kind: "library", item: item }
    setHeroButtons("Continuar")
    showHero({
        "id": item._id, "type": item.type, "name": item.name, "logo": Library_str(item.logo), "background": Library_str(item.background),
        "year": Addons_text(item.year), "progressText": Library_continueLabel(item)
    })
    m.heroTask = Ui_runTask("meta", { addons: m.global.session.addons, type: item.type, id: item._id }, "onHeroMeta")
end sub

sub setHeroFromCatalog(meta as object)
    m.heroSource = { kind: "catalog", meta: meta }
    setHeroButtons("Reproducir")
    data = {}
    data.Append(meta)
    showHero(data)
end sub

sub setHeroButtons(primary as string)
    m.hero.buttons = [{ id: "play", label: primary, icon: "pkg:/images/icon_play.png" }, { id: "info", label: "Más info", icon: "pkg:/images/icon_info.png" }]
end sub

sub showHero(data as object)
    m.hero.data = data
    ' Mi lista covers the hero area: keep it hidden there, build() shows it again.
    if m.myList.visible then return
    m.hero.visible = true
    m.skeleton.visible = false
    if m.top.isInFocusChain() and not m.nav.isInFocusChain() and not m.rows.hasFocus() then m.hero.setFocus(true)
end sub

' The library item has no description, rating or genres: fill them from the meta when it arrives.
sub onHeroMeta(evt as object)
    r = evt.getData()
    if not r.ok or m.heroSource = invalid or m.heroSource.kind <> "library" or m.heroSource.item._id <> r.meta.id then return
    data = m.hero.data
    for each key in ["description", "imdbRating", "runtime", "genres", "year", "logo"]
        value = r.meta[key]
        if GetInterface(value, "ifString") <> invalid and value <> "" and (key <> "logo" or data.logo = "") then data[key] = value
    end for
    m.hero.data = data
end sub

' Loads the focused catalog row and the next three, so the slow device only parses what is near.
sub loadAround(index as integer)
    for idx = index to index + 3
        row = m.rowsRoot.getChild(idx)
        if row <> invalid
            entry = m.catalogs[row.id]
            if entry <> invalid and entry.state = "idle"
                entry.state = "loading"
                m.tasks[row.id] = Ui_runTask("catalog", { cat: entry.cat }, "onCatalog", row.id)
            end if
        end if
    end for
end sub

sub onCatalog(evt as object)
    task = evt.getRoSGNode()
    r = evt.getData()
    m.tasks.Delete(task.id)
    row = Ui_childById(m.rowsRoot, task.id)
    if row = invalid then return
    if not r.ok or r.metas.Count() = 0
        print "[Home] catalog "; row.title; " skipped: "; r.error
        m.rowsRoot.removeChild(row)
        m.catalogs.Delete(task.id)
        applyRowSizes()
        if m.rowsRoot.getChildCount() = 0
            m.message.text = "No se pudo cargar ningún catálogo. Probá buscar."
            m.skeleton.visible = false
            ' Never leave focus on an empty RowList, but don't steal it while another screen is on top.
            if m.top.visible and m.rows.hasFocus() then m.nav.setFocus(true)
        else
            ' Rows below shift up into view and would otherwise stay grey until the next focus change.
            index = m.rows.itemFocused
            if index < 0 then index = 0
            loadAround(index)
        end if
        return
    end if
    row.removeChildrenIndex(row.getChildCount(), 0)
    for each meta in r.metas
        Ui_fillItem(row.createChild("ContentNode"), meta, meta.releaseInfo)
    end for
    m.catalogs[task.id].state = "done"
    if m.heroSource = invalid and not m.myList.visible then setHeroFromCatalog(r.metas[0])
end sub

sub onItemFocused()
    if m.rows.itemFocused >= 0 then loadAround(m.rows.itemFocused)
end sub

sub onItemSelected()
    sel = m.rows.rowItemSelected
    row = m.rowsRoot.getChild(sel[0])
    if row = invalid then return
    item = row.getChild(sel[1])
    if item = invalid or item.metaId = invalid or item.metaId = "" then return
    m.lastFocus = m.rows
    if row.id = "continue"
        it = Library_find(m.global.session.library, item.metaId)
        if it <> invalid
            playLibraryItem(it)
            return
        end if
    end if
    m.top.navigate = Ui_detailNav(item)
end sub

sub onHeroAction()
    src = m.heroSource
    if src = invalid then return
    m.lastFocus = m.hero
    if m.hero.action = "info"
        if src.kind = "library"
            m.top.navigate = { action: "push", screen: "DetailScreen", params: { id: src.item._id, type: src.item.type, name: src.item.name, poster: Library_str(src.item.poster) } }
        else
            m.top.navigate = { action: "push", screen: "DetailScreen", params: { id: src.meta.id, type: src.meta.type, name: src.meta.name, poster: src.meta.poster } }
        end if
        return
    end if
    if src.kind = "library"
        playLibraryItem(src.item)
    else if src.meta.type = "movie"
        goPlay({ id: src.meta.id, type: "movie", name: src.meta.name, poster: src.meta.poster, year: Left(src.meta.year, 4) }, src.meta.id, src.meta.name)
    else
        ' A series needs an episode: the detail screen picks it.
        m.top.navigate = { action: "push", screen: "DetailScreen", params: { id: src.meta.id, type: src.meta.type, name: src.meta.name, poster: src.meta.poster } }
    end if
end sub

' "Continuar" plays the video the user was watching.
sub playLibraryItem(it as object)
    ' Snapshots (hero, cards) can be older than the session: resume from the current state.
    fresh = Library_find(m.global.session.library, it._id)
    if fresh <> invalid then it = fresh
    ' Watched to the end: replaying would overwrite that progress. The detail screen knows the next episode
    ' (and starts it); a finished movie opens there for the user to choose.
    if Library_atEnd(it)
        m.top.navigate = { action: "push", screen: "DetailScreen", params: { id: it._id, type: it.type, name: it.name, poster: Library_str(it.poster), playNext: it.type = "series" } }
        return
    end if
    videoId = it._id
    label = it.name
    if type(it.state) = "roAssociativeArray" and Library_str(it.state.video_id) <> "" then videoId = it.state.video_id
    ep = Meta_parseVideoId(videoId)
    if it.type = "series" and ep <> invalid then label = it.name + " · T" + ep.season.ToStr() + " E" + ep.episode.ToStr()
    meta = { id: it._id, type: it.type, name: it.name, poster: Library_str(it.poster), year: "" }
    ' Source ranking pushes other years' releases down, so movies need their year; library items rarely have it.
    if it.type = "movie"
        meta.year = Left(Addons_text(it.year), 4)
        if meta.year = "" and heroText("id") = it._id then meta.year = Left(heroText("year"), 4)
        if meta.year = ""
            m.pendingPlay = { meta: meta, videoId: videoId, label: label }
            m.playTask = Ui_runTask("meta", { addons: m.global.session.addons, type: "movie", id: it._id }, "onPlayMeta")
            return
        end if
    end if
    goPlay(meta, videoId, label)
end sub

function heroText(key as string) as string
    if type(m.hero.data) <> "roAssociativeArray" then return ""
    v = m.hero.data[key]
    if GetInterface(v, "ifString") <> invalid then return v
    return ""
end function

sub onPlayMeta(evt as object)
    r = evt.getData()
    p = m.pendingPlay
    if p = invalid then return
    m.pendingPlay = invalid
    if r.ok
        p.meta.year = Left(r.meta.year, 4)
        if p.meta.year = "" then p.meta.year = Left(r.meta.releaseInfo, 4)
    end if
    goPlay(p.meta, p.videoId, p.label)
end sub

' Plays the best source right away, trying the next ones if it fails.
sub goPlay(meta as object, videoId as string, label as string)
    m.top.navigate = { action: "push", screen: "PlayerScreen", params: { meta: meta, videoId: videoId, label: label, autoplay: true } }
end sub

sub onNavChosen()
    index = m.nav.chosen
    if index = 4
        m.lastFocus = m.nav
        m.top.navigate = { action: "push", screen: "SearchScreen", params: {} }
        return
    end if
    m.nav.selected = index
    if index = 3
        showMyList()
        return
    end if
    kinds = ["", "movie", "series"]
    build(kinds[index])
end sub

sub showMyList()
    session = m.global.session
    m.hero.visible = false
    m.skeleton.visible = false
    m.rows.visible = false
    m.message.text = ""
    m.myList.libraryLoaded = session.libraryLoaded
    m.myList.library = session.library
    m.myList.visible = true
end sub

sub onMyListSelected()
    it = m.myList.selectedItem
    m.lastFocus = m.myList
    m.top.navigate = { action: "push", screen: "DetailScreen", params: { id: it._id, type: it.type, name: it.name, poster: Library_str(it.poster) } }
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if m.myList.visible
        if key = "down" and m.nav.isInFocusChain()
            m.myList.setFocus(true)
            return true
        end if
        if key = "up" and m.myList.isInFocusChain()
            m.nav.setFocus(true)
            return true
        end if
        return false
    end if
    if key = "up"
        if m.rows.hasFocus() and m.hero.visible
            m.hero.setFocus(true)
        else if m.rows.hasFocus() or m.hero.isInFocusChain()
            m.nav.setFocus(true)
        else
            return false
        end if
        return true
    end if
    if key = "down"
        if m.nav.isInFocusChain() and m.hero.visible
            m.hero.setFocus(true)
        else if (m.nav.isInFocusChain() or m.hero.isInFocusChain()) and m.rowsRoot.getChildCount() > 0
            m.rows.setFocus(true)
        else
            return false
        end if
        return true
    end if
    return false
end function
