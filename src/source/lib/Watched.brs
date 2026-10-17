' Stremio's per-episode "watched" flags, read only.
' Format: "<anchor video id>:<length>:<base64 zlib bitfield>"; bit i (LSB first) is video i in season/episode order.

' Minimal zlib inflate: stored and fixed-Huffman blocks, which is what Stremio's small bitfields use.
' Returns invalid for anything else (dynamic Huffman, truncated or non-zlib data).
function Watched_inflate(data as object) as dynamic
    if data.Count() < 3 or (data[0] and &h0F) <> 8 then return invalid
    st = { data: data, pos: 2, bit: 0, ok: true }
    out = CreateObject("roByteArray")
    lbase = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
    lext = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
    dbase = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]
    dext = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]
    final = 0
    while final = 0
        final = Watched_bits(st, 1)
        btype = Watched_bits(st, 2)
        if not st.ok then return invalid
        if btype = 0
            ' Stored block: byte-aligned LEN, NLEN, then raw bytes.
            if st.bit > 0
                st.pos = st.pos + 1
                st.bit = 0
            end if
            if st.pos + 4 > data.Count() then return invalid
            length = data[st.pos] + data[st.pos + 1] * 256
            st.pos = st.pos + 4
            if st.pos + length > data.Count() then return invalid
            for i = 0 to length - 1
                out.Push(data[st.pos + i])
            end for
            st.pos = st.pos + length
        else if btype = 1
            while true
                sym = Watched_fixedSymbol(st)
                if not st.ok or sym < 0 then return invalid
                if sym < 256
                    out.Push(sym)
                else if sym = 256
                    exit while
                else
                    li = sym - 257
                    if li >= lbase.Count() then return invalid
                    length = lbase[li] + Watched_bits(st, lext[li])
                    ' Distance codes are 5 bits, Huffman (MSB-first) order.
                    di = Watched_code(st, 5)
                    if di >= dbase.Count() then return invalid
                    dist = dbase[di] + Watched_bits(st, dext[di])
                    if not st.ok or dist > out.Count() then return invalid
                    start = out.Count() - dist
                    for i = 0 to length - 1
                        out.Push(out[start + i])
                    end for
                end if
            end while
        else
            return invalid
        end if
    end while
    return out
end function

' Reads n bits LSB-first (header fields and extra bits).
function Watched_bits(st as object, n as integer) as integer
    value = 0
    for i = 0 to n - 1
        if st.pos >= st.data.Count()
            st.ok = false
            return 0
        end if
        b = (st.data[st.pos] >> st.bit) and 1
        value = value or (b << i)
        st.bit = st.bit + 1
        if st.bit = 8
            st.bit = 0
            st.pos = st.pos + 1
        end if
    end for
    return value
end function

' Reads n bits as a Huffman code (first bit is the most significant).
function Watched_code(st as object, n as integer) as integer
    code = 0
    for i = 1 to n
        code = (code << 1) or Watched_bits(st, 1)
    end for
    return code
end function

' Fixed literal/length code (RFC 1951 3.2.6): 7, 8 or 9 bits. Returns -1 for an invalid code.
function Watched_fixedSymbol(st as object) as integer
    code = Watched_code(st, 7)
    if code <= &h17 then return 256 + code
    code = (code << 1) or Watched_bits(st, 1)
    if code >= &h30 and code <= &hBF then return code - &h30
    if code >= &hC0 and code <= &hC7 then return 280 + code - &hC0
    code = (code << 1) or Watched_bits(st, 1)
    if code >= &h190 and code <= &h1FF then return 144 + code - &h190
    return -1
end function

' Watched video ids (id -> true). videoIds must be in season/episode order, as Addons_parseMeta sorts them.
function Watched_videoIds(watched as string, videoIds as object) as object
    seen = {}
    parts = watched.Split(":")
    if parts.Count() < 3 then return seen
    length = parts[parts.Count() - 2].ToInt()
    if length <= 0 then return seen
    anchorParts = []
    for i = 0 to parts.Count() - 3
        anchorParts.Push(parts[i])
    end for
    anchor = anchorParts.Join(":")
    data = CreateObject("roByteArray")
    data.FromBase64String(parts[parts.Count() - 1])
    bits = Watched_inflate(data)
    if bits = invalid then return seen
    ' Episodes added after Stremio saved the flags move the anchor: shift every bit by the same amount.
    offset = 0
    for i = 0 to videoIds.Count() - 1
        if videoIds[i] = anchor
            offset = i - (length - 1)
            exit for
        end if
    end for
    ' The length comes from the string: never loop past the bits that actually exist (this runs on the render thread).
    last = length
    if last > bits.Count() * 8 then last = bits.Count() * 8
    for i = 0 to last - 1
        if ((bits[i >> 3] >> (i and 7)) and 1) = 1
            j = i + offset
            if j >= 0 and j < videoIds.Count() then seen[videoIds[j]] = true
        end if
    end for
    return seen
end function
