' Formats a duration in milliseconds as "m:ss" or "h:mm:ss".
function Format_time(ms as dynamic) as string
    total = Int(ms / 1000)
    h = total \ 3600
    mm = (total mod 3600) \ 60
    s = total mod 60
    if h > 0 then return h.ToStr() + ":" + Format_pad(mm) + ":" + Format_pad(s)
    return mm.ToStr() + ":" + Format_pad(s)
end function

function Format_pad(n as integer) as string
    if n < 10 then return "0" + n.ToStr()
    return n.ToStr()
end function

' Local clock time when the video ends: "Termina a las HH:MM".
function Format_endsAt(hour as integer, minute as integer, remainingSec as integer) as string
    total = (hour * 60 + minute + Int(remainingSec / 60)) mod (24 * 60)
    return Format_pad(Int(total / 60)) + ":" + Format_pad(total mod 60)
end function
