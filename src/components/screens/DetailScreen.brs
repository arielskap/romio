' Detail: hero-style header with Continuar / Desde el principio / Mi lista, and below it
' related titles and cast (movies) or season tabs and episode cards (series).
sub init()
    m.hero = m.top.findNode("hero")
    m.skeleton = m.top.findNode("skeleton")
    m.message = m.top.findNode("message")
    m.lower = m.top.findNode("lower")
    m.related = m.top.findNode("related")
    m.cast = m.top.findNode("cast")
    m.seasons = m.top.findNode("seasons")
    m.episodes = m.top.findNode("episodes")
    m.epOverview = m.top.findNode("epOverview")
    m.meta = invalid
    m.lastFocus = invalid
    m.episodeList = []
    m.relatedReady = false
    m.hero.observeField("action", "onHeroAction")
    m.related.observeField("rowItemSelected", "onRelatedSelected")
    ' Focus moving in or out of these rows scrolls the lower part.
    m.related.observeField("focusedChild", "layoutLower")
    m.cast.observeField("focusedChild", "layoutLower")
    m.seasons.observeField("chosen", "onSeasonChosen")
    m.episodes.observeField("rowItemFocused", "onEpisodeFocused")
    m.episodes.observeField("rowItemSelected", "onEpisodeSelected")
    m.top.observeField("active", "onActive")
end sub

sub onActive()
    p = m.top.params
    ' Reading m.global.session deep-copies the whole library, so it is read once here.
    session = m.global.session
    m.authKey = session.authKey
    m.addons = session.addons
    m.libraryLoaded = session.libraryLoaded = true
    m.item = Library_find(session.library, p.id)
    if m.meta = invalid
        Ui_parkFocus(m.top)
        m.task = Ui_runTask("meta", { addons: m.addons, type: p.type, id: p.id }, "onMeta")
        return
    end if
    ' Back from sources or the player: progress, watched marks and buttons may have changed.
    renderHeader()
    if isSeries() then showEpisodes(m.currentSeason, focusedEpisodeId())
    if m.lastFocus <> invalid then m.lastFocus.setFocus(true) else m.hero.setFocus(true)
end sub

function isSeries() as boolean
    return m.meta.type = "series" and m.meta.videos.Count() > 0
end function

sub onMeta(evt as object)
    r = evt.getData()
    p = m.top.params
    if not r.ok
        m.message.text = r.error
        m.meta = { "id": p.id, "type": p.type, "name": p.name, "poster": p.poster, "description": "", "background": "", "releaseInfo": "", "videos": [], "cast": [] }
    else
        m.meta = r.meta
    end if
    m.skeleton.visible = false
    m.hero.visible = true
    renderHeader()
    if isSeries()
        setupSeries()
    else
        setupMovie()
    end if
    m.hero.setFocus(true)
    ' Home's "Continuar" on a finished episode lands here to start the next one; nothing new yet stays here.
    if Library_bool(p.playNext) and isSeries() and Library_atEnd(m.item)
        target = seriesTarget()
        if target.ep.id <> Library_str(m.item.state.video_id)
            m.lastFocus = m.hero
            goPlay(target.ep.id, episodeLabel(target.ep), false)
        end if
    end if
end sub

' ---------- Header and buttons ----------

sub renderHeader()
    data = {}
    for each key in ["id", "name", "logo", "background", "description", "imdbRating", "year", "runtime", "genres", "certification", "director"]
        data[key] = m.meta[key]
    end for
    buttons = []
    if isSeries()
        target = seriesTarget()
        label = "Reproducir"
        if target.resumeMs > 0 or target.fromState then label = "Continuar"
        label = label + " T" + target.ep.season.ToStr() + " · E" + target.ep.episode.ToStr()
        if target.resumeMs > 0
            data["progress"] = Library_progress(m.item)
            data["progressText"] = remainingText()
        end if
        buttons.Push({ id: "play", label: label, icon: "pkg:/images/icon_play.png" })
        if target.resumeMs > 0 then buttons.Push({ id: "restart", label: "Desde el principio", icon: "pkg:/images/icon_restart.png" })
    else
        resume = Library_resumeMs(m.item, m.meta.id)
        if resume > 0
            data["progress"] = Library_progress(m.item)
            data["progressText"] = remainingText()
            buttons.Push({ id: "play", label: "Continuar", icon: "pkg:/images/icon_play.png" })
            buttons.Push({ id: "restart", label: "Desde el principio", icon: "pkg:/images/icon_restart.png" })
        else
            buttons.Push({ id: "play", label: "Reproducir", icon: "pkg:/images/icon_play.png" })
        end if
    end if
    buttons.Push({ id: "sources", label: "Fuentes", icon: "pkg:/images/icon_sources.png" })
    ' Without the server library, writing an item could overwrite it: no list button then.
    if m.libraryLoaded
        if Library_inList(m.item)
            buttons.Push({ id: "list", label: "En mi lista", icon: "pkg:/images/icon_check.png" })
        else
            buttons.Push({ id: "list", label: "Mi lista", icon: "pkg:/images/icon_add.png" })
        end if
    end if
    m.hero.data = data
    m.hero.buttons = buttons
end sub

function remainingText() as string
    st = m.item.state
    left = Library_num(st.duration) - Library_num(st.timeOffset)
    if left < 0 then left = 0
    text = "Quedan " + Format_time(left)
    if isSeries()
        ep = Meta_parseVideoId(Library_str(st.video_id))
        if ep <> invalid then text = "T" + ep.season.ToStr() + " · E" + ep.episode.ToStr() + "  ·  " + text
    end if
    return text
end function

sub onHeroAction()
    action = m.hero.action
    m.lastFocus = m.hero
    if action = "list"
        toggleList()
        return
    end if
    videoId = m.meta.id
    label = m.meta.name
    if isSeries()
        target = seriesTarget()
        videoId = target.ep.id
        label = episodeLabel(target.ep)
    end if
    if action = "sources"
        goSources(videoId, label)
    else
        goPlay(videoId, label, action = "restart")
    end if
end sub

' Shown right away; the Task then applies it to the server's copy, which may carry newer progress from another device.
sub toggleList()
    if m.listTask <> invalid or not m.libraryLoaded then return
    m.listBefore = m.item
    inList = not Library_inList(m.item)
    m.listMeta = { "id": m.meta.id, "name": m.meta.name, "type": m.meta.type, "poster": m.meta.poster, "background": m.meta.background, "logo": m.meta.logo, "year": Left(Library_str(m.meta.year), 4) }
    showListItem(Library_setInList(m.item, m.listMeta, inList, Library_nowIso()))
    m.message.text = ""
    m.listTask = Ui_runTask("setInList", { authKey: m.authKey, meta: m.listMeta, inList: inList }, "onListSaved")
end sub

sub onListSaved(evt as object)
    m.listTask = invalid
    r = evt.getData()
    if r.item <> invalid
        showListItem(r.item)
        ' A failed save stays in the pending queue and is retried at the next boot, like progress.
        if not r.ok then m.message.text = "No se pudo actualizar tu lista. Se va a reintentar."
        return
    end if
    ' Couldn't read the server copy: nothing was saved, undo the change on screen.
    before = m.listBefore
    if before = invalid then before = Library_newItem(m.listMeta, Library_nowIso())
    showListItem(before)
    m.message.text = "No se pudo actualizar tu lista."
end sub

sub showListItem(item as object)
    session = m.global.session
    session.library = Library_upsert(session.library, item)
    m.global.session = session
    m.item = item
    renderHeader()
end sub

' Only movies use the year to rank sources; series episodes rarely carry the show's year.
function playMeta() as object
    year = ""
    if m.meta.type = "movie"
        year = Left(Library_str(m.meta.year), 4)
        if year = "" then year = Left(Library_str(m.meta.releaseInfo), 4)
    end if
    return { id: m.meta.id, type: m.meta.type, name: m.meta.name, poster: m.meta.poster, year: year }
end function

' Plays the best source right away, trying the next ones if it fails.
sub goPlay(videoId as string, label as string, fromStart as boolean)
    m.top.navigate = { action: "push", screen: "PlayerScreen", params: { meta: playMeta(), videoId: videoId, label: label, autoplay: true, fromStart: fromStart, videos: playVideos() } }
end sub

' Series pass their episodes so the player can offer Episodios and Siguiente without loading them again.
function playVideos() as object
    if isSeries() and type(m.meta.videos) = "roArray" then return m.meta.videos
    return []
end function

sub goSources(videoId as string, label as string)
    resuming = Library_resumeMs(m.item, videoId) > 0
    m.top.navigate = { action: "push", screen: "StreamsScreen", params: { meta: playMeta(), videoId: videoId, label: label, fromStart: false, resuming: resuming } }
end sub

' ---------- Movies: related titles and cast ----------

sub setupMovie()
    base = Meta_baseName(m.meta.name)
    if base <> ""
        ' Grey tiles hold the related row's place while it loads, so the cast doesn't jump down later.
        root = CreateObject("roSGNode", "ContentNode")
        row = root.createChild("ContentNode")
        row.title = "Más de " + base
        Ui_placeholder(row, 8)
        m.related.content = root
        m.related.visible = true
        m.relatedTask = Ui_runTask("search", { addons: m.addons, query: base }, "onRelated")
    end if
    cast = m.meta.cast
    if cast = invalid or cast.Count() = 0 then return
    root = CreateObject("roSGNode", "ContentNode")
    row = root.createChild("ContentNode")
    row.title = "Reparto"
    for each c in cast
        node = row.createChild("ContentNode")
        node.addFields({ character: c.character })
        node.title = c.name
        node.HDPosterUrl = c.photo
    end for
    m.cast.content = root
    m.cast.visible = true
    placeCast()
end sub

sub onRelated(evt as object)
    r = evt.getData()
    movies = []
    if not r.ok then r.metas = []
    for each meta in r.metas
        if meta.type = "movie" then movies.Push(meta)
    end for
    relatedMetas = Meta_related(movies, m.meta.id, Meta_baseName(m.meta.name), Library_nowIso())
    if relatedMetas.Count() = 0
        m.related.visible = false
        placeCast()
        return
    end if
    root = CreateObject("roSGNode", "ContentNode")
    row = root.createChild("ContentNode")
    row.title = "Más de " + Meta_baseName(m.meta.name)
    for each meta in relatedMetas
        Ui_fillItem(row.createChild("ContentNode"), meta, Left(Library_str(meta.year), 4))
    end for
    m.related.content = root
    m.relatedReady = true
    placeCast()
end sub

' Cast goes under the related row (or its loading tiles). An empty related search removes the row: a focused cast moves up with it.
sub placeCast()
    if m.related.visible then m.cast.translation = [80, 460] else m.cast.translation = [80, 0]
    layoutLower()
end sub

sub onRelatedSelected()
    if not m.relatedReady then return
    sel = m.related.rowItemSelected
    item = m.related.content.getChild(0).getChild(sel[1])
    if item = invalid then return
    m.lastFocus = m.related
    m.top.navigate = Ui_detailNav(item)
end sub

' Related titles and cast don't fit under the header: scroll the lower part up and dim the header behind it.
' A cast row alone (no related row above it) fits without scrolling.
sub layoutLower()
    if m.related.hasFocus() or (m.cast.hasFocus() and m.related.visible)
        m.lower.translation = [0, 195]
        m.hero.dimmed = true
    else
        m.lower.translation = [0, 655]
        m.hero.dimmed = false
    end if
end sub

' ---------- Series: seasons and episodes ----------

sub setupSeries()
    m.seasonList = Meta_seasons(m.meta.videos)
    target = seriesTarget()
    labels = []
    selected = 0
    for i = 0 to m.seasonList.Count() - 1
        s = m.seasonList[i]
        if s = 0 then labels.Push("Especiales") else labels.Push("Temporada " + s.ToStr())
        if s = target.ep.season then selected = i
    end for
    m.seasons.items = labels
    m.seasons.selected = selected
    m.seasons.visible = true
    m.episodes.visible = true
    showEpisodes(target.ep.season, target.ep.id)
end sub

' The episode "Continuar"/"Reproducir" points at: the one in progress, the next one after a finished
' episode, or the first released episode.
function seriesTarget() as object
    videos = m.meta.videos
    stateVid = ""
    if m.item <> invalid and type(m.item.state) = "roAssociativeArray" then stateVid = Library_str(m.item.state.video_id)
    index = Meta_indexOfVideo(videos, stateVid)
    if stateVid <> "" and videos[index].id = stateVid
        resume = Library_resumeMs(m.item, stateVid)
        if resume > 0 then return { ep: videos[index], resumeMs: resume, fromState: true }
        if index + 1 < videos.Count() and isReleased(videos[index + 1]) then return { ep: videos[index + 1], resumeMs: 0, fromState: true }
        return { ep: videos[index], resumeMs: 0, fromState: true }
    end if
    for each v in videos
        if v.season > 0 and isReleased(v) then return { ep: v, resumeMs: 0, fromState: false }
    end for
    return { ep: videos[0], resumeMs: 0, fromState: false }
end function

function isReleased(ep as object) as boolean
    return Meta_isReleased(ep, Library_nowIso())
end function

function episodeLabel(ep as object) as string
    return m.meta.name + " · T" + ep.season.ToStr() + " E" + ep.episode.ToStr()
end function

sub onSeasonChosen()
    index = m.seasons.chosen
    m.seasons.selected = index
    showEpisodes(m.seasonList[index], "")
    m.episodes.setFocus(true)
end sub

' Watched episodes (id -> true). Decoding inflates the bitfield in BrightScript, so it only runs again
' when the library item's watched field changed (season switches and returns from the player reuse it).
function watchedMap() as object
    if m.item = invalid or type(m.item.state) <> "roAssociativeArray" then return {}
    watched = Library_str(m.item.state.watched)
    if m.watchedKey = invalid or m.watchedKey <> watched
        ids = []
        for each v in m.meta.videos
            ids.Push(v.id)
        end for
        m.watchedMap = Watched_videoIds(watched, ids)
        m.watchedKey = watched
    end if
    return m.watchedMap
end function

sub showEpisodes(season as integer, focusVideoId as string)
    m.currentSeason = season
    m.episodeList = Meta_episodes(m.meta.videos, season)
    watched = watchedMap()
    stateVid = ""
    if m.item <> invalid and type(m.item.state) = "roAssociativeArray" then stateVid = Library_str(m.item.state.video_id)
    root = CreateObject("roSGNode", "ContentNode")
    row = root.createChild("ContentNode")
    for each ep in m.episodeList
        node = row.createChild("ContentNode")
        subtitle = ""
        resume = Library_resumeMs(m.item, ep.id)
        if resume >= 1000 then subtitle = "vas por " + Format_time(resume)
        if not isReleased(ep) then subtitle = "Se estrena el " + Mid(ep.released, 9, 2) + "/" + Mid(ep.released, 6, 2)
        progress = 0.0
        if ep.id = stateVid and resume > 0 then progress = Library_progress(m.item)
        title = "E" + ep.episode.ToStr()
        if ep.title <> "" then title = title + " · " + ep.title
        thumb = Library_str(ep.thumbnail)
        if thumb = "" then thumb = Art_background(m.meta.id, Library_str(m.meta.background))
        node.addFields({ metaId: ep.id, subtitle: subtitle, landscape: true, progress: progress, finished: watched.DoesExist(ep.id) })
        node.title = title
        node.HDPosterUrl = thumb
    end for
    m.episodes.content = root
    index = Meta_indexOfVideo(m.episodeList, focusVideoId)
    m.episodes.jumpToRowItem = [0, index]
    showOverview(index)
end sub

function focusedEpisodeId() as string
    sel = m.episodes.rowItemFocused
    if sel = invalid or sel.Count() < 2 or sel[1] < 0 or sel[1] >= m.episodeList.Count() then return ""
    return m.episodeList[sel[1]].id
end function

sub onEpisodeFocused()
    sel = m.episodes.rowItemFocused
    if sel <> invalid and sel.Count() = 2 then showOverview(sel[1])
end sub

sub showOverview(index as integer)
    m.epOverview.text = ""
    if index >= 0 and index < m.episodeList.Count() then m.epOverview.text = Library_str(m.episodeList[index].overview)
end sub

sub onEpisodeSelected()
    ep = m.episodeList[m.episodes.rowItemSelected[1]]
    if ep = invalid or not isReleased(ep) then return
    m.lastFocus = m.episodes
    goPlay(ep.id, episodeLabel(ep), false)
end sub

' ---------- Focus ----------

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or m.meta = invalid then return false
    if key = "down"
        if m.hero.isInFocusChain()
            if isSeries()
                m.seasons.setFocus(true)
            else if m.relatedReady
                m.related.setFocus(true)
            else if m.cast.visible
                m.cast.setFocus(true)
            else
                return false
            end if
            return true
        end if
        if m.related.hasFocus() and m.cast.visible
            m.cast.setFocus(true)
            return true
        end if
        if m.seasons.isInFocusChain()
            m.episodes.setFocus(true)
            return true
        end if
        return false
    end if
    if key = "up"
        if m.cast.hasFocus() and m.relatedReady
            m.related.setFocus(true)
        else if m.cast.hasFocus() or m.related.hasFocus() or m.seasons.isInFocusChain()
            m.hero.setFocus(true)
        else if m.episodes.hasFocus()
            m.seasons.setFocus(true)
        else
            return false
        end if
        return true
    end if
    return false
end function
