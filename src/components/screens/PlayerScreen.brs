sub init()
    m.video = m.top.findNode("video")
    m.overlay = m.top.findNode("overlay")
    m.status = m.top.findNode("status")
    m.detail = m.top.findNode("detail")
    m.choices = m.top.findNode("choices")
    m.menu = m.top.findNode("menu")
    m.subsList = m.top.findNode("subsList")
    m.menuTitle = m.top.findNode("menuTitle")
    m.panel = ""
    m.panelFrom = "video"
    m.subSize = ""
    m.subBg = ""
    m.audioLang = ""
    m.audioTrack = ""
    m.subLang = ""
    m.audioApplied = false
    m.toast = m.top.findNode("toast")
    m.toastBox = m.top.findNode("toastBox")
    m.syncBox = m.top.findNode("syncBox")
    m.syncValue = m.top.findNode("syncValue")
    m.saveTimer = m.top.findNode("saveTimer")
    m.convertTimer = m.top.findNode("convertTimer")
    m.toastTimer = m.top.findNode("toastTimer")
    m.watchTimer = m.top.findNode("watchTimer")
    m.controls = m.top.findNode("controls")
    m.nextCard = m.top.findNode("nextCard")
    m.nextTimer = m.top.findNode("nextTimer")
    m.nextDismissed = false
    m.videos = []
    m.controlsTimer = m.top.findNode("controlsTimer")
    m.seekPending = -1
    m.initialized = false
    m.exited = false
    m.failed = false
    m.itemChanged = false
    m.subtitles = []
    m.activeSubUrl = ""
    m.subOffsetMs = 0
    m.video.notificationInterval = 1
    m.video.observeField("state", "onState")
    m.video.observeField("position", "onPosition")
    m.saveTimer.observeField("fire", "saveProgress")
    m.convertTimer.observeField("fire", "onConvertTimeout")
    m.toastTimer.observeField("fire", "hideToast")
    m.watchTimer.observeField("fire", "onWatchTick")
    m.controlsTimer.observeField("fire", "onControlsTimer")
    m.controls.observeField("action", "onControlAction")
    m.nextCard.observeField("action", "onNextCardAction")
    m.nextTimer.observeField("fire", "onNextTick")
    m.choices.observeField("itemSelected", "onChoice")
    m.subsList.observeField("itemSelected", "onMenuChosen")
    m.top.observeField("active", "onActive")
end sub

sub onActive()
    if m.initialized
        ' Back from RdKeyScreen: retry only if a new key was saved, else stay on the choices.
        rdKey = m.global.session.rdKey
        if rdKey <> m.rdKey
            m.rdKey = rdKey
            playIndex(m.index, m.forceTranscode)
        else
            m.choices.setFocus(true)
        end if
        return
    end if
    m.initialized = true
    p = m.top.params
    ' Reading m.global.session deep-copies the whole library, so it is read once here.
    session = m.global.session
    m.authKey = session.authKey
    m.addons = session.addons
    m.rdKey = session.rdKey
    m.libraryLoaded = session.libraryLoaded = true
    m.meta = p.meta
    m.videoId = p.videoId
    m.label = p.label
    m.streams = p.streams
    m.item = Library_find(session.library, m.meta.id)
    m.itemKnown = m.item <> invalid
    if m.item = invalid then m.item = Library_newItem(m.meta, Library_nowIso())
    m.resumeMs = Library_resumeMs(m.item, m.videoId)
    ' "Desde el principio": start at 0:00; saving earlier positions then is what the user asked for.
    ' Audio and subtitle language chosen in the previous episode, carried by "Siguiente" and "Episodios".
    if type(p.prefs) = "roAssociativeArray"
        m.audioLang = Addons_str(p.prefs.audioLang)
        m.subLang = Addons_str(p.prefs.subLang)
    end if
    ' Series need the episode list for Episodios, Siguiente and the end card; from home it isn't passed.
    if type(p.videos) = "roArray" then m.videos = p.videos
    if m.meta.type = "series" and m.videos.Count() = 0
        m.metaTask = Ui_runTask("meta", { addons: m.addons, type: "series", id: m.meta.id }, "onMeta")
    end if
    m.fromStart = Addons_isTrue(p.fromStart)
    if m.fromStart then m.resumeMs = 0
    ' Autoplay (Continuar/Reproducir) looks for the sources itself and tries the best ones in order.
    m.autoplay = Addons_isTrue(p.autoplay)
    m.attempts = 1
    m.autoplayClock = CreateObject("roTimespan")
    m.index = 0
    resetAttempt()
    if type(p.streams) <> "roArray"
        m.streams = []
        showOverlay("Buscando fuentes…", "")
        m.task = Ui_runTask("streams", { addons: m.addons, type: m.meta.type, videoId: m.videoId, year: Library_str(m.meta.year), resuming: m.resumeMs > 0 }, "onStreams")
        return
    end if
    playIndex(p.index, false)
end sub

sub onMeta(evt as object)
    if m.exited then return
    r = evt.getData()
    if r.ok and type(r.meta.videos) = "roArray" then m.videos = r.meta.videos
end sub

sub onStreams(evt as object)
    if m.exited then return
    r = evt.getData()
    if not r.ok
        showFailure(r.error, false)
        return
    end if
    m.streams = r.streams
    playIndex(0, false)
end sub

' Per-attempt state. Also set before the first source is known, since Back can save progress at any moment.
sub resetAttempt()
    m.direct = false
    m.failed = false
    m.started = false
    m.stallRetries = 0
    m.errorRetries = 0
    m.stallWaitedSec = 0
    m.resumeFallback = false
    m.lastPos = 0
    m.lastSmooth = 0
    m.furthestSmooth = 0
    m.watchedMs = 0
end sub

sub playIndex(i as integer, forceTranscode as boolean)
    ' The previous attempt's timers and Task must not act on this one (a direct start retried as a conversion
    ' would otherwise restart the rejected URL or resolve two sources at once).
    stopTimers()
    if m.task <> invalid then m.task.unobserveField("result")
    m.index = i
    m.forceTranscode = forceTranscode
    resetAttempt()
    m.video.control = "stop"
    s = m.streams[i]
    ' The file name's guess; the real check happens in Flows_play, which may still convert a "Directa" source.
    if Sources_str(s.compat) = "direct" and not forceTranscode
        status = "Preparando " + Sources_qualityText(s) + " · Directa"
        detail = "Debería arrancar enseguida."
    else
        status = "Preparando " + Sources_qualityText(s) + " · Convertida"
        detail = "Real-Debrid está convirtiendo el video para tu Roku. La primera vez puede tardar hasta un minuto y medio."
    end if
    if m.attempts > 1 then status = "Probando otra fuente (" + m.attempts.ToStr() + " de 3) · " + status
    showOverlay(status, detail)
    m.task = Ui_runTask("play", { rdKey: m.rdKey, addons: m.addons, type: m.meta.type, videoId: m.videoId, stream: { url: s.url, filename: s.filename, addon: s.addon }, forceTranscode: forceTranscode }, "onResolved")
end sub

sub onResolved(evt as object)
    if m.exited then return
    r = evt.getData()
    if not r.ok
        ' Flows_play already remembers files Real-Debrid doesn't have; other errors aren't the file's fault.
        sourceFailed(r.error, r.keyProblem, false)
        return
    end if
    m.subtitles = r.subtitles
    m.subOffsetMs = 0
    m.direct = r.direct
    content = CreateObject("roSGNode", "ContentNode")
    content.url = r.url
    content.streamFormat = r.streamFormat
    content.title = m.label
    content.subtitleTracks = Subs_tracks(r.subtitles)
    m.toastPending = ""
    m.activeSubUrl = ""
    if type(r.subStyle) = "roAssociativeArray"
        m.subSize = Addons_str(r.subStyle.size)
        m.subBg = Addons_str(r.subStyle.background)
        applySubStyle()
    end if
    pick = r.pick
    if m.subLang = "off"
        pick = -1
    else if m.subLang <> ""
        langPick = Subs_pickLang(r.subtitles, m.subLang)
        if langPick >= 0 then pick = langPick
    end if
    if pick >= 0
        m.activeSubUrl = r.subtitles[pick].url
        m.video.globalCaptionMode = "On"
        m.video.subtitleTrack = m.activeSubUrl
    else
        m.video.globalCaptionMode = "Off"
        if m.subLang <> "off"
            langName = "español"
            if m.subLang <> "" then langName = LCase(m.subLang)
            m.toastPending = "No encontré subtítulos en " + langName + ". Apretá la flecha para arriba para elegir otro idioma."
        end if
    end if
    if m.direct and m.toastPending = "" then m.toastPending = "Reproducción directa: podés adelantar libremente."
    startContent(content, Int(m.resumeMs / 1000))
end sub

' Starts one playback attempt: every (re)start goes through here so the watchdogs reset together.
sub startContent(content as object, playStartSec as integer)
    m.failed = false
    content.PlayStart = playStartSec
    m.content = content
    resetStallWatch()
    ' A reload (sync, restart, retry) brings the tracks back to the default: pick the chosen audio again.
    m.audioApplied = false
    ' Until the new content plays, its position is near 0: a save now would rewind the progress.
    m.saveTimer.control = "stop"
    m.watchTimer.control = "start"
    ' A direct file starts in seconds when the Roku can play it; a conversion can take a minute and a half.
    if m.direct then m.convertTimer.duration = 30 else m.convertTimer.duration = 90
    m.convertTimer.control = "start"
    m.video.content = content
    m.video.control = "play"
end sub

sub restartAt(seconds as integer, message as string)
    showOverlay(message, "")
    startContent(m.content.clone(true), seconds)
end sub

sub resetStallWatch()
    m.stuckTicks = 0
    m.lastTickPos = -1
end sub

sub stopTimers()
    m.nextTimer.control = "stop"
    m.controlsTimer.control = "stop"
    m.watchTimer.control = "stop"
    m.convertTimer.control = "stop"
    m.saveTimer.control = "stop"
end sub

' Real-Debrid only converts segments requested in order from the start, so jumping past what it
' has converted (resuming or seeking a fresh file) buffers forever instead of failing. The state
' flickers between playing and buffering there, so stalls are detected by position not advancing.
sub onWatchTick()
    ' Direct play seeks freely: a stall there is the network, not unconverted content.
    if not Playback_watchActive(m.started, m.resumeMs, m.resumeFallback, m.video.state, m.direct) then return
    position = m.video.position
    if position > m.lastTickPos + 0.5
        m.stuckTicks = 0
    else
        m.stuckTicks = m.stuckTicks + 1
    end if
    m.lastTickPos = position
    ' Seeks are caught sooner (15s) than a slow first start or resume (25s).
    threshold = 5
    if m.started then threshold = 3
    if m.stuckTicks >= threshold
        m.stuckTicks = 0
        onStalled()
    end if
end sub

sub onStalled()
    print "[Player] stalled at "; m.video.position; " last smooth "; m.lastSmooth
    if Playback_shouldFallBack(m.resumeMs, m.resumeFallback, m.furthestSmooth)
        restartFromZero(resumeFailedToast())
        return
    end if
    ' A short jump past what Real-Debrid converted usually loads if given time; a long one never does.
    jumpSec = m.video.position - m.lastSmooth
    if m.started and Playback_stallAction(jumpSec, m.stallWaitedSec) = "wait"
        m.stallWaitedSec = m.stallWaitedSec + 15
        showToast("Real-Debrid está convirtiendo hasta " + Format_time(Int(m.video.position) * 1000) + "…")
        return
    end if
    m.stallWaitedSec = 0
    if m.started and m.stallRetries < 1
        m.stallRetries = m.stallRetries + 1
        positionSec = Int(m.lastSmooth)
        m.toastPending = "Real-Debrid todavía no convirtió esa parte. Volviste a " + Format_time(positionSec * 1000) + "."
        restartAt(positionSec, "Volviendo a " + Format_time(positionSec * 1000) + "…")
        return
    end if
    m.video.control = "stop"
    showFailure("Real-Debrid todavía no convirtió esta parte del video.", false, true)
end sub

' Restarts at 0:00 keeping the furthest known position as the resume point, so saves can't erase it.
function resumeFailedToast() as string
    return "No se pudo retomar en " + Format_time(m.resumeMs) + ". Empezó desde el principio; adelantá en un rato."
end function

' Direct play is a best guess from the file header: if the Roku rejects it or it never starts,
' convert the same source instead.
function retryTranscoded() as boolean
    if not m.direct or m.started then return false
    playIndex(m.index, true)
    return true
end function

sub restartFromZero(toast as string)
    m.resumeMs = Playback_nextSourceResume(m.resumeMs, m.lastSmooth)
    m.started = false
    m.saveTimer.control = "stop"
    m.resumeFallback = true
    m.toastPending = toast
    restartAt(0, "Empezando desde el principio…")
end sub

sub onState()
    state = m.video.state
    print "[Player] state "; state; " position "; m.video.position
    if state = "playing"
        if m.controls.visible and not m.controls.barOnly then hideControls()
        m.convertTimer.control = "stop"
        m.overlay.visible = false
        m.started = true
        if not m.audioApplied and (m.audioTrack <> "" or m.audioLang <> "")
            ' availableAudioTracks fills in once playback starts.
            m.audioApplied = true
            track = Tracks_pickAudio(m.video.availableAudioTracks, m.audioTrack, m.audioLang)
            if track <> "" and track <> m.video.currentAudioTrack then m.video.audioTrack = track
        end if
        m.saveTimer.control = "start"
        focusPlayback()
        if m.toastPending <> ""
            showToast(m.toastPending)
            m.toastPending = ""
        end if
    else if state = "paused"
        resetStallWatch()
        saveProgress()
    else if state = "error"
        onVideoError()
    else if state = "finished"
        if m.nextCard.visible and not m.nextDismissed
            playEpisode(m.nextUp)
            return
        end if
        saveProgress()
        exitPlayer()
    end if
end sub

sub onPosition()
    if m.video.state <> "playing" then return
    positionSec = m.video.position
    delta = positionSec - m.lastPos
    if delta > 0 and delta < 5 then m.watchedMs = m.watchedMs + Int(delta * 1000)
    ' Normal playback advances ~1s per notification; stalls flicker forward by milliseconds.
    if delta >= 0.5 and delta < 5
        m.lastSmooth = positionSec
        if positionSec > m.furthestSmooth then m.furthestSmooth = positionSec
        m.stallRetries = 0
        m.errorRetries = 0
        m.stallWaitedSec = 0
    end if
    m.lastPos = positionSec
    if m.controls.visible and m.seekPending < 0 then m.controls.positionSec = positionSec
    if m.meta.type = "series" then checkNextCard(positionSec)
end sub

sub onVideoError()
    print "[Player] error "; m.video.errorCode; " "; m.video.errorMsg; " | "; m.video.errorStr
    if retryTranscoded() then return
    if not m.direct and Playback_shouldFallBack(m.resumeMs, m.resumeFallback, m.furthestSmooth)
        restartFromZero(resumeFailedToast())
        return
    end if
    if m.started and m.errorRetries < 2
        m.errorRetries = m.errorRetries + 1
        positionSec = Int(m.lastSmooth)
        restartAt(positionSec, "Retomando en " + Format_time(positionSec * 1000) + "…")
        return
    end if
    sourceFailed("El video no se pudo reproducir (" + m.video.errorMsg + ").", false, true)
end sub

sub onConvertTimeout()
    if m.started and m.video.state = "playing" then return
    if retryTranscoded() then return
    m.video.control = "stop"
    sourceFailed("Real-Debrid no terminó de preparar este video.", false, false)
end sub

' A source that never played: autoplay moves on to the next one or to the sources screen; otherwise show the failure.
' noteFile: remember the file as failed for a week (only when the file itself didn't play).
sub sourceFailed(text as string, keyProblem as boolean, noteFile as boolean)
    action = Playback_autoNext(m.autoplay, m.started, keyProblem, m.attempts, m.index, m.streams.Count(), m.autoplayClock.TotalSeconds())
    print "[Player] source "; m.index; " failed (try "; m.attempts; "): "; action
    if action = "stop"
        showFailure(text, keyProblem)
        return
    end if
    stopTimers()
    m.video.control = "stop"
    m.failed = true
    if noteFile then m.noteTask = Ui_runTask("noteFailedFile", { filename: Sources_str(m.streams[m.index].filename) }, "onNoted")
    if action = "next"
        m.resumeMs = Playback_nextSourceResume(m.resumeMs, m.lastSmooth)
        m.attempts = m.attempts + 1
        playIndex(m.index + 1, false)
        return
    end if
    m.exited = true
    if m.task <> invalid then m.task.unobserveField("result")
    ' The sources just tried show gray, so the screen doesn't recommend one of them again.
    for i = 0 to m.index
        m.streams[i].note = "Falló recién"
    end for
    m.top.navigate = {
        action: "replace", screen: "StreamsScreen",
        params: { meta: m.meta, videoId: m.videoId, label: m.label, streams: m.streams, resuming: m.resumeMs > 0, fromStart: m.fromStart, notice: "No pude reproducir las mejores fuentes. Elegí otra." }
    }
end sub

sub onNoted()
end sub

sub hideFloating()
    m.menu.visible = false
    m.syncBox.visible = false
    m.toastBox.visible = false
    ' Loading and failure screens take over: the controls and the end card must not keep the keys underneath.
    m.controls.visible = false
    m.seekPending = -1
    m.controlsTimer.control = "stop"
    m.nextTimer.control = "stop"
    m.nextCard.visible = false
end sub

sub showOverlay(status as string, detail as string)
    hideFloating()
    m.status.text = status
    m.detail.text = detail
    m.choices.visible = false
    m.overlay.visible = true
    ' Hidden children (failure choices, controls, panels) would otherwise keep the keys under the overlay.
    Ui_parkFocus(m.top)
end sub

sub showFailure(text as string, keyProblem as boolean, offerStart = false as boolean)
    stopTimers()
    ' After a failure the Video position is no longer trustworthy, so nothing is saved.
    m.failed = true
    hideFloating()
    m.status.text = "No se pudo reproducir"
    m.detail.text = text
    m.choiceActions = []
    root = CreateObject("roSGNode", "ContentNode")
    if offerStart then addChoice(root, "Ver desde el principio", "start")
    if m.index + 1 < m.streams.Count() then addChoice(root, "Probar la siguiente fuente", "next")
    if keyProblem then addChoice(root, "Cargar clave de Real-Debrid", "rdkey")
    addChoice(root, "Volver", "back")
    m.choices.content = root
    m.choices.visible = true
    m.overlay.visible = true
    m.choices.setFocus(true)
end sub

sub addChoice(root as object, title as string, action as string)
    c = root.createChild("ContentNode")
    c.title = title
    m.choiceActions.Push(action)
end sub

sub onChoice()
    action = m.choiceActions[m.choices.itemSelected]
    if action = "start"
        restartFromZero("")
    else if action = "next"
        if m.index + 1 >= m.streams.Count() then return
        m.resumeMs = Playback_nextSourceResume(m.resumeMs, m.lastSmooth)
        playIndex(m.index + 1, false)
    else if action = "rdkey"
        m.top.navigate = { action: "push", screen: "RdKeyScreen", params: {} }
    else
        exitPlayer()
    end if
end sub

sub showToast(text as string)
    m.toast.text = text
    m.toastBox.visible = true
    m.toastTimer.control = "start"
end sub

sub hideToast()
    m.toastBox.visible = false
end sub

' ---------- Panels: subtitles (with settings), audio ----------

' from: "controls" when opened from the pause controls (closing returns there), "video" from the up key.
sub openPanel(panel as string, title as string, items as object, from as string)
    m.panel = panel
    m.panelFrom = from
    m.menuTitle.text = title
    root = CreateObject("roSGNode", "ContentNode")
    for each item in items
        c = root.createChild("ContentNode")
        c.title = item.title
        ' Set on every item: a reused list keeps the previous icon's space otherwise.
        c.HDListItemIconUrl = item.icon
        c.HDListItemIconSelectedUrl = ""
        if item.icon <> "" then c.HDListItemIconSelectedUrl = item.iconFocused
    end for
    m.controls.visible = false
    m.subsList.content = root
    m.menu.visible = true
    m.subsList.setFocus(true)
end sub

sub openSubtitleMenu(from as string)
    m.menuSubs = Subs_menuOrder(m.subtitles)
    items = [{ title: "Ajustes", icon: "pkg:/images/icon_gear.png", iconFocused: "pkg:/images/icon_gear_dark.png" }]
    for each title in Subs_menuLabels(m.menuSubs, m.activeSubUrl)
        items.Push({ title: title, icon: "" })
    end for
    openPanel("subs", "Subtítulos", items, from)
end sub

sub openSubSettings()
    items = [{ title: Tracks_sizeLabel(m.subSize), icon: "" }, { title: Tracks_backgroundLabel(m.subBg), icon: "" }]
    ' Sync only makes sense with a subtitle on.
    if m.activeSubUrl <> "" then items.Push({ title: "Sincronizar (" + Subs_formatOffset(m.subOffsetMs) + ")", icon: "" })
    openPanel("settings", "Ajustes de subtítulos", items, m.panelFrom)
end sub

sub openAudioMenu(from as string)
    m.menuAudio = Tracks_audioItems(m.video.availableAudioTracks)
    current = m.video.currentAudioTrack
    items = []
    for each a in m.menuAudio
        title = a.label
        if a.track = current then title = title + " (activo)"
        items.Push({ title: title, icon: "" })
    end for
    openPanel("audio", "Audio", items, from)
end sub

' ---------- Series: episodes, next episode and the end card ----------

function findVideo(id as string) as dynamic
    for each v in m.videos
        if Library_str(v.id) = id then return v
    end for
    return invalid
end function

function nextEpisode() as dynamic
    if m.meta.type <> "series" then return invalid
    return Meta_nextEpisode(m.videos, m.videoId, Library_nowIso())
end function

function episodeText(ep as object) as string
    text = "E" + ep.episode.ToStr()
    if Library_str(ep.title) <> "" then text = text + " · " + ep.title
    return text
end function

' Left/right in the panel change season.
sub openEpisodes(season as integer)
    m.episodeSeasons = Meta_seasons(m.videos)
    m.episodeSeason = season
    m.menuEpisodes = Meta_episodes(m.videos, season)
    items = []
    focusIndex = 0
    todayIso = Library_nowIso()
    for i = 0 to m.menuEpisodes.Count() - 1
        ep = m.menuEpisodes[i]
        title = episodeText(ep)
        if ep.id = m.videoId
            title = title + " (viendo)"
            focusIndex = i
        else if not Meta_isReleased(ep, todayIso)
            title = title + " (se estrena el " + Mid(ep.released, 9, 2) + "/" + Mid(ep.released, 6, 2) + ")"
        end if
        items.Push({ title: title, icon: "" })
    end for
    title = "Temporada " + season.ToStr()
    if season = 0 then title = "Especiales"
    if m.episodeSeasons.Count() > 1 then title = "<  " + title + "  >"
    openPanel("episodes", title, items, "controls")
    m.subsList.jumpToItem = focusIndex
end sub

sub shiftSeason(deltaIndex as integer)
    seasons = m.episodeSeasons
    for i = 0 to seasons.Count() - 1
        if seasons[i] = m.episodeSeason
            j = i + deltaIndex
            if j >= 0 and j < seasons.Count() then openEpisodes(seasons[j])
            return
        end if
    end for
end sub

' Saves what the guards allow and replaces this player with one for the episode, keeping audio/subtitle choices.
sub playEpisode(ep as dynamic)
    if ep = invalid or m.exited then return
    saveProgress()
    m.exited = true
    if m.task <> invalid then m.task.unobserveField("result")
    stopTimers()
    m.video.control = "stop"
    if m.itemChanged
        session = m.global.session
        session.library = Library_upsert(session.library, m.item)
        m.global.session = session
    end if
    m.top.navigate = {
        action: "replace", screen: "PlayerScreen", dropBelow: "StreamsScreen",
        params: { meta: m.meta, videoId: ep.id, label: m.meta.name + " · T" + ep.season.ToStr() + " E" + ep.episode.ToStr(), autoplay: true, videos: m.videos, prefs: { audioLang: m.audioLang, subLang: m.subLang } }
    }
end sub

sub checkNextCard(positionSec as dynamic)
    if m.nextCard.visible then return
    ' Looking up the next episode scans every video: only near the end.
    if not Playback_showNextCard(positionSec, m.video.duration, m.nextDismissed) then return
    upcoming = nextEpisode()
    if upcoming = invalid then return
    m.nextUp = upcoming
    m.nextCard.episode = { title: "T" + upcoming.season.ToStr() + " · " + episodeText(upcoming), thumbnail: Library_str(upcoming.thumbnail) }
    m.nextSeconds = 8
    m.nextCard.seconds = m.nextSeconds
    m.nextCard.visible = true
    if not m.controls.visible then focusPlayback()
    m.nextTimer.control = "start"
end sub

sub onNextTick()
    if m.exited then return
    ' The countdown waits while a panel or the sync box is open, so it doesn't jump episodes behind it.
    if m.menu.visible or m.syncBox.visible then return
    m.nextSeconds = m.nextSeconds - 1
    if m.nextSeconds <= 0
        playEpisode(m.nextUp)
        return
    end if
    m.nextCard.seconds = m.nextSeconds
end sub

sub dismissNextCard()
    m.nextTimer.control = "stop"
    m.nextCard.visible = false
    m.nextDismissed = true
    focusPlayback()
end sub

sub onNextCardAction()
    if m.nextCard.action = "play" then playEpisode(m.nextUp) else dismissNextCard()
end sub

sub closePanel()
    m.menu.visible = false
    m.panel = ""
    ' The OK that picked an item also bubbles to onKeyEvent; it must not pause the video.
    m.panelClosed = CreateObject("roTimespan")
    if m.panelFrom = "controls" then showControls(false) else focusPlayback()
end sub

sub applySubStyle()
    if m.subSize = "" and m.subBg = "" then return
    m.video.captionStyle = Tracks_captionStyle(m.subSize, m.subBg)
end sub

sub onMenuChosen()
    i = m.subsList.itemSelected
    if m.panel = "settings"
        if i = 0 or i = 1
            if i = 0 then m.subSize = Tracks_nextSize(m.subSize) else m.subBg = Tracks_nextBackground(m.subBg)
            applySubStyle()
            m.styleTask = Ui_runTask("saveSubStyle", { size: m.subSize, background: m.subBg }, "onNoted")
            openSubSettings()
            m.subsList.jumpToItem = i
        else
            m.menu.visible = false
            openSync()
        end if
        return
    end if
    if m.panel = "episodes"
        if i < m.menuEpisodes.Count()
            ep = m.menuEpisodes[i]
            ' The episode being watched just closes the panel; an unreleased one has nothing to play yet.
            if ep.id = m.videoId
                closePanel()
            else if Meta_isReleased(ep, Library_nowIso())
                playEpisode(ep)
            end if
        end if
        return
    end if
    if m.panel = "audio"
        if i < m.menuAudio.Count()
            m.video.audioTrack = m.menuAudio[i].track
            m.audioTrack = m.menuAudio[i].track
            m.audioLang = m.menuAudio[i].lang
        end if
        closePanel()
        return
    end if
    ' Subtitles: "Ajustes", "Sin subtítulos", then the list.
    if i = 0
        openSubSettings()
        return
    end if
    i = i - 1
    if i = 0
        m.activeSubUrl = ""
        m.subLang = "off"
        m.video.globalCaptionMode = "Off"
        closePanel()
        return
    end if
    m.activeSubUrl = m.menuSubs[i - 1].url
    m.subLang = Subs_langName(m.menuSubs[i - 1].lang)
    closePanel()
    ' A shifted copy is a separate track: a new choice starts in sync again (offset 0).
    if m.subOffsetMs <> 0
        m.subOffsetMs = 0
        reloadSubtitles(Subs_tracks(m.subtitles), m.activeSubUrl)
        return
    end if
    m.video.globalCaptionMode = "On"
    m.video.subtitleTrack = m.activeSubUrl
end sub

sub openSync()
    m.menu.visible = false
    m.syncPendingMs = m.subOffsetMs
    m.syncValue.text = "Subtítulos: " + Subs_formatOffset(m.syncPendingMs)
    m.syncBox.visible = true
    m.syncBox.setFocus(true)
    ' The OK that picked "Sincronizar" in the list also bubbles up here; it must not apply.
    m.syncOpened = CreateObject("roTimespan")
end sub

sub closeSync()
    m.syncBox.visible = false
    if m.panelFrom = "controls" and m.video.state = "paused" then showControls(false) else focusPlayback()
end sub

' The Roku has no subtitle delay and changing tracks while playing loses sync (verified on the
' device), so a shifted copy is written by the Task and the video reloads at the same position.
sub applySync()
    closeSync()
    if m.syncPendingMs = m.subOffsetMs then return
    if m.syncPendingMs = 0
        m.subOffsetMs = 0
        reloadSubtitles(Subs_tracks(m.subtitles), m.activeSubUrl)
        return
    end if
    showToast("Sincronizando subtítulos…")
    m.syncTask = Ui_runTask("shiftSubtitle", { url: m.activeSubUrl, offsetMs: m.syncPendingMs }, "onShifted")
end sub

sub onShifted(evt as object)
    if m.exited then return
    r = evt.getData()
    if not r.ok
        showToast(r.error)
        return
    end if
    m.subOffsetMs = m.syncPendingMs
    tracks = Subs_tracks(m.subtitles)
    tracks.Push({ "Language": "spa", "TrackName": r.path, "Description": "Sincronizado " + Subs_formatOffset(m.subOffsetMs) })
    reloadSubtitles(tracks, r.path)
end sub

sub reloadSubtitles(tracks as object, activeTrack as string)
    content = m.content.clone(true)
    content.subtitleTracks = tracks
    showOverlay("Aplicando subtítulos…", "")
    startContent(content, Int(m.video.position))
    m.video.globalCaptionMode = "On"
    m.video.subtitleTrack = activeTrack
end sub

sub saveProgress()
    positionMs = Playback_savePosition(Int(m.video.position * 1000), m.lastSmooth, m.resumeMs, m.direct)
    durationMs = Int(m.video.duration * 1000)
    if durationMs <= 0 then return
    if not Playback_canSave({ started: m.started, failed: m.failed, fellBack: m.resumeFallback, resumeMs: m.resumeMs, positionMs: positionMs, libraryLoaded: m.libraryLoaded, itemKnown: m.itemKnown }) then return
    m.item = Library_withProgress(m.item, m.videoId, positionMs, durationMs, m.watchedMs, Library_nowIso())
    m.itemChanged = true
    m.watchedMs = 0
    m.saveTask = Ui_runTask("saveProgress", { authKey: m.authKey, item: m.item }, "onSaved")
end sub

sub onSaved(evt as object)
    r = evt.getData()
    if r.ok then print "[Player] progress saved" else print "[Player] progress kept pending: "; r.error
end sub

sub exitPlayer()
    m.exited = true
    if m.task <> invalid then m.task.unobserveField("result")
    stopTimers()
    m.video.control = "stop"
    ' Only Home and Detail read the library, and only after this screen is popped: write it once.
    if m.itemChanged
        session = m.global.session
        session.library = Library_upsert(session.library, m.item)
        m.global.session = session
    end if
    m.top.navigate = { action: "back" }
end sub

' ---------- Controls (the Video's own UI is off: enableUI="false") ----------

' The Video keeps handling remote keys (its own trickplay) whenever it has focus, even with enableUI off.
' An empty node takes focus during playback so every key bubbles to onKeyEvent; focusing the screen itself
' would leave focus on whichever child had it (the hidden controls' buttons).
sub focusPlayback()
    ' An open panel or the sync box keeps the keys until it closes (closing calls this again).
    if m.menu.visible or m.syncBox.visible then return
    ' The end card keeps the keys while it counts down, so Back dismisses it instead of leaving.
    if m.nextCard.visible and not m.nextDismissed
        m.nextCard.setFocus(true)
        return
    end if
    Ui_parkFocus(m.top)
end sub

sub pauseWithControls()
    ' A paused countdown would start the next episode behind the controls; it shows again after resuming.
    m.nextTimer.control = "stop"
    m.nextCard.visible = false
    m.video.control = "pause"
    showControls(false)
end sub

' barOnly: just the progress bar while seeking, hidden again after 3 seconds.
sub showControls(barOnly as boolean)
    m.controls.barOnly = barOnly
    updateControls()
    m.controls.visible = true
    m.controlsTimer.control = "stop"
    if barOnly
        m.controlsTimer.control = "start"
        return
    end if
    m.seekPending = -1
    m.controls.buttons = controlButtons()
    m.controls.focusIndex = 1
    m.controls.setFocus(true)
end sub

function controlButtons() as object
    buttons = [
        { id: "back10", label: "", icon: "pkg:/images/icon_back10.png" },
        { id: "resume", label: "Seguir", icon: "pkg:/images/icon_play.png" },
        { id: "fwd10", label: "", icon: "pkg:/images/icon_fwd10.png" }
    ]
    ' Converted streams may lose the extra audio tracks: the button only appears when there is a choice.
    tracks = m.video.availableAudioTracks
    if type(tracks) = "roArray" and tracks.Count() > 1 then buttons.Push({ id: "audio", label: "Audio", icon: "pkg:/images/icon_audio.png" })
    buttons.Push({ id: "subs", label: "Subtítulos", icon: "pkg:/images/icon_subs.png" })
    if m.videos.Count() > 0 then buttons.Push({ id: "episodes", label: "Episodios", icon: "pkg:/images/icon_episodes.png" })
    if nextEpisode() <> invalid then buttons.Push({ id: "next", label: "Siguiente", icon: "pkg:/images/icon_next.png" })
    return buttons
end function

sub updateControls()
    positionSec = m.video.position
    durationSec = m.video.duration
    ' Seeking shows only the bar: the title, episode and end time stay hidden, so they aren't rebuilt per key.
    m.controls.durationSec = durationSec
    if m.controls.barOnly
        m.controls.positionSec = positionSec
        return
    end if
    remaining = 0
    if durationSec > positionSec then remaining = Int(durationSec - positionSec)
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    mode = "Convertida"
    if m.direct then mode = "Directa"
    quality = mode
    if m.index < m.streams.Count() then quality = Sources_qualityText(m.streams[m.index]) + " · " + mode
    subtitle = ""
    ep = Meta_parseVideoId(m.videoId)
    if m.meta.type = "series" and ep <> invalid
        subtitle = "T" + ep.season.ToStr() + " · E" + ep.episode.ToStr()
        current = findVideo(m.videoId)
        if current <> invalid and Library_str(current.title) <> "" then subtitle = subtitle + " — " + current.title
    end if
    endsAt = ""
    if durationSec > 0 then endsAt = "Termina a las " + Format_endsAt(now.GetHours(), now.GetMinutes(), remaining)
    m.controls.info = { title: m.meta.name, subtitle: subtitle, quality: quality, endsAt: endsAt }
    m.controls.positionSec = positionSec
end sub

sub hideControls()
    m.controlsTimer.control = "stop"
    m.controls.visible = false
    m.seekPending = -1
    focusPlayback()
end sub

sub onControlsTimer()
    if m.controls.barOnly then hideControls()
end sub

sub resumeFromControls()
    hideControls()
    m.video.control = "resume"
end sub

' Repeated presses add up from the last target, since the Video's position only moves once the seek lands.
sub seekBy(deltaSec as integer)
    base = m.video.position
    if m.controls.visible and m.seekPending >= 0 then base = m.seekPending
    target = Playback_seekTarget(base, deltaSec, m.video.duration)
    showControls(true)
    m.seekPending = target
    m.controls.positionSec = target
    m.video.seek = target
end sub

sub onControlAction()
    action = m.controls.action
    if action = "resume"
        resumeFromControls()
    else if action = "audio"
        openAudioMenu("controls")
    else if action = "subs"
        openSubtitleMenu("controls")
    else if action = "episodes"
        current = findVideo(m.videoId)
        season = 1
        if current <> invalid then season = current.season
        openEpisodes(season)
    else if action = "next"
        playEpisode(nextEpisode())
    else if action = "back10" or action = "fwd10"
        deltaSec = 10
        if action = "back10" then deltaSec = -10
        hideControls()
        ' Seeking a paused Video plays again once it lands (autoplayAfterSeek).
        seekBy(deltaSec)
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if m.controls.visible and not m.controls.barOnly
        ' The buttons take left/right/OK; Back and Play close the controls and keep watching.
        if key = "back" or key = "play"
            resumeFromControls()
            return true
        end if
        return false
    end if
    if m.syncBox.visible
        if key = "left" or key = "right"
            deltaMs = 500
            if key = "left" then deltaMs = -500
            m.syncPendingMs = m.syncPendingMs + deltaMs
            if m.syncPendingMs > 60000 then m.syncPendingMs = 60000
            if m.syncPendingMs < -60000 then m.syncPendingMs = -60000
            m.syncValue.text = "Subtítulos: " + Subs_formatOffset(m.syncPendingMs)
        else if key = "OK"
            if m.syncOpened.TotalMilliseconds() > 500 then applySync()
        else if key = "back"
            closeSync()
        end if
        return true
    end if
    if m.nextCard.visible and m.nextCard.isInFocusChain()
        if key = "back"
            dismissNextCard()
            return true
        end if
        return false
    end if
    if m.menu.visible and m.panel = "episodes" and (key = "left" or key = "right")
        if key = "left" then shiftSeason(-1) else shiftSeason(1)
        return true
    end if
    if m.menu.visible and key = "back"
        if m.panel = "settings" then openSubtitleMenu(m.panelFrom) else closePanel()
        return true
    end if
    if key = "up" and Playback_canOpenSubtitles(m.started, m.menu.visible, m.overlay.visible)
        openSubtitleMenu("video")
        return true
    end if
    if key = "OK" and m.panelClosed <> invalid
        if m.panelClosed.TotalMilliseconds() < 400 then return true
    end if
    if m.started and not m.overlay.visible and not m.menu.visible
        if key = "OK" or key = "play"
            pauseWithControls()
            return true
        end if
        seeks = { left: -10, right: 10, rewind: -60, fastforward: 60 }
        if seeks.DoesExist(key)
            seekBy(seeks[key])
            return true
        end if
    end if
    if key = "back"
        saveProgress()
        exitPlayer()
        return true
    end if
    return false
end function
