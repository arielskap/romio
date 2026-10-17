' Player decisions kept pure so they can be tested off the Video node.

' Switching source keeps the furthest known position as the resume point, so it is never saved over.
function Playback_nextSourceResume(resumeMs as dynamic, lastSmoothSec as dynamic) as dynamic
    reached = Int(lastSmoothSec * 1000)
    if reached > resumeMs then return reached
    return resumeMs
end function

' s: { started, failed, fellBack, resumeMs, positionMs, libraryLoaded, itemKnown }
function Playback_canSave(s as object) as boolean
    if not s.started or s.failed then return false
    ' Without the server library, a new item would replace (and un-library) the real one.
    if not s.libraryLoaded and not s.itemKnown then return false
    return Library_shouldSave(s.fellBack, s.resumeMs, s.positionMs)
end function

' Startup without a resume point, or after falling back to 0:00, is governed by the 90s convert timer.
' Direct files seek natively, so the transcode stall watchdog never applies to them.
function Playback_watchActive(started as boolean, resumeMs as dynamic, fellBack as boolean, state as string, direct as boolean) as boolean
    if direct or state = "paused" then return false
    if not started and (resumeMs = 0 or fellBack) then return false
    return true
end function

function Playback_canOpenSubtitles(started as boolean, menuVisible as boolean, overlayVisible as boolean) as boolean
    return started and not menuVisible and not overlayVisible
end function

' A forward seek into unconverted content reports the target as position; save what actually played.
' The resume point is the floor: before playback advances smoothly, lastSmooth is still 0.
' Direct files really are at the reported position.
function Playback_savePosition(positionMs as dynamic, lastSmoothSec as dynamic, resumeMs as dynamic, direct as boolean) as dynamic
    if direct then return positionMs
    floorMs = Int(lastSmoothSec * 1000)
    if resumeMs > floorMs then floorMs = resumeMs
    if positionMs > floorMs + 5000 then return floorMs
    return positionMs
end function

' Real-Debrid converts only from the start, so an unreached resume point means starting over.
' furthestSmoothSec is the furthest smooth position of this attempt, so seeking back doesn't count.
function Playback_shouldFallBack(resumeMs as dynamic, fellBack as boolean, furthestSmoothSec as dynamic) as boolean
    return resumeMs > 0 and not fellBack and furthestSmoothSec * 1000 < resumeMs - 5000
end function

' A stall after a seek with transcoding: Real-Debrid keeps converting forward, so a short jump
' (up to 2 minutes) usually loads if given time. Wait up to a minute, then go back.
function Playback_stallAction(jumpSec as dynamic, waitedSec as dynamic) as string
    if jumpSec <= 120 and waitedSec < 60 then return "wait"
    return "return"
end function

' What autoplay does after a source fails before playing: "next" source, the "sources" screen once three tries
' (or all sources) are used up, or "stop" (show the failure) for key problems, sources that already played,
' and sources the user picked by hand.
' elapsedSec: since autoplay started trying; past four minutes the user picks instead of waiting for more tries.
function Playback_autoNext(autoplay as boolean, started as boolean, keyProblem as boolean, attempts as integer, index as integer, count as integer, elapsedSec as integer) as string
    if not autoplay or started or keyProblem then return "stop"
    if attempts < 3 and index + 1 < count and elapsedSec < 240 then return "next"
    return "sources"
end function

' Where a ±N seconds jump lands: never before the start, and a few seconds short of the end
' (seeking to the very end finishes the video). Without a known duration only the start limits it.
function Playback_seekTarget(positionSec as dynamic, deltaSec as integer, durationSec as dynamic) as integer
    target = Int(positionSec) + deltaSec
    if durationSec > 0 and target > Int(durationSec) - 3 then target = Int(durationSec) - 3
    if target < 0 then target = 0
    return target
end function

' The "Siguiente episodio" card: the last 40 seconds of an episode that has a released next one,
' unless the user chose to watch the credits. Very short videos (under a minute) never show it.
function Playback_showNextCard(positionSec as dynamic, durationSec as dynamic, dismissed as boolean) as boolean
    if dismissed or durationSec <= 60 then return false
    return durationSec - positionSec <= 40
end function
