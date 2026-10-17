sub init()
    m.qtext = m.top.findNode("qtext")
    m.dot = m.top.findNode("dot")
    m.phrase = m.top.findNode("phrase")
    m.pills = m.top.findNode("pills")
    m.filename = m.top.findNode("filename")
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    s = c.stream
    if type(s) <> "roAssociativeArray" then return
    m.qtext.text = Sources_qualityText(s)
    color = Sources_color(s)
    m.dot.color = color
    m.phrase.color = color
    m.phrase.text = Sources_phrase(s)
    Ui_pills(m.pills, Sources_chips(s), 170, 40)
    m.filename.text = Sources_str(s.filename)
    ' Gray sources (failed before, cinema copies, other years, samples) stay listed but dimmed.
    if Sources_str(s.note) <> "" then m.top.opacity = 0.7 else m.top.opacity = 1
end sub
