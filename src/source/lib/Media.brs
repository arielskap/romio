' Codec sniffing from the first bytes of a file (hex string), to decide if the Roku can play it as is.

' Hex form of an ASCII needle, computed once per scope.
function Media_needle(text as string) as string
    if m.mediaNeedles = invalid then m.mediaNeedles = {}
    if not m.mediaNeedles.DoesExist(text)
        b = CreateObject("roByteArray")
        b.FromAsciiString(text)
        m.mediaNeedles[text] = b.ToHexString()
    end if
    return m.mediaNeedles[text]
end function

' Byte offset of `text` inside `hex`, or -1. Matches must start on a byte boundary.
function Media_find(hex as string, text as string) as integer
    needle = Media_needle(text)
    start = 0
    while true
        i = hex.Instr(start, needle)
        if i < 0 then return -1
        if i mod 2 = 0 then return i \ 2
        start = i + 1
    end while
    return -1
end function

' MKV CodecIDs and MP4 fourccs; the first audio declared is the one the Roku plays by default.
function Media_info(hex as string) as object
    video = ""
    if Media_find(hex, "V_MPEGH/ISO/HEVC") >= 0 or Media_find(hex, "hvc1") >= 0 or Media_find(hex, "hev1") >= 0
        video = "hevc"
    else if Media_find(hex, "V_MPEG4/ISO/AVC") >= 0 or Media_find(hex, "avc1") >= 0
        video = "h264"
    end if
    audio = ""
    best = -1
    for each c in [["A_AAC", "aac"], ["A_MPEG/L3", "mp3"], ["A_AC3", "ac3"], ["A_EAC3", "eac3"], ["A_DTS", "dts"], ["A_TRUEHD", "truehd"], ["A_FLAC", "flac"], ["A_OPUS", "opus"], ["mp4a", "aac"], ["ac-3", "ac3"], ["ec-3", "eac3"]]
        at = Media_find(hex, c[0])
        if at >= 0 and (best < 0 or at < best)
            best = at
            audio = c[1]
        end if
    end for
    return { video: video, audio: audio }
end function

' The Roku Express decodes H.264 with AAC/MP3 natively; anything else goes through Real-Debrid's transcode.
function Media_canDirect(info as object) as boolean
    return info.video = "h264" and (info.audio = "aac" or info.audio = "mp3")
end function

' MP4 box header at `offset` in bytes: { size, type, header } (size as LongInteger: boxes can pass 4 GB),
' or invalid when the header doesn't fit.
function Media_boxHeader(bytes as object, offset as dynamic) as dynamic
    if offset + 8 > bytes.Count() then return invalid
    size = Media_uint32(bytes, offset)
    kind = Chr(bytes[offset + 4]) + Chr(bytes[offset + 5]) + Chr(bytes[offset + 6]) + Chr(bytes[offset + 7])
    header = 8
    if size = 1
        if offset + 16 > bytes.Count() then return invalid
        size = Media_uint32(bytes, offset + 8) * 4294967296& + Media_uint32(bytes, offset + 12)
        header = 16
    end if
    return { size: size, type: kind, header: header }
end function

function Media_uint32(bytes as object, offset as dynamic) as dynamic
    return bytes[offset] * 16777216& + bytes[offset + 1] * 65536& + bytes[offset + 2] * 256& + bytes[offset + 3]
end function
