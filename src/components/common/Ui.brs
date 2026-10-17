' Shared helpers for screens (render thread).

' The app's name lives only in the manifest's title.
function Ui_appName() as string
    return CreateObject("roAppInfo").GetTitle()
end function

function Ui_runTask(op as string, args as object, callback as string, tag = "" as string) as object
    t = CreateObject("roSGNode", "ApiTask")
    t.id = tag
    t.op = op
    t.args = args
    t.observeField("result", callback)
    t.control = "run"
    return t
end function

sub Ui_fillItem(node as object, meta as object, subtitle as string)
    node.addFields({ metaId: meta.id, metaType: meta.type, subtitle: subtitle })
    node.title = meta.name
    node.HDPosterUrl = meta.poster
end sub

' Inverse of Ui_fillItem: the navigate payload that opens the item's detail.
function Ui_detailNav(item as object) as object
    return { action: "push", screen: "DetailScreen", params: { id: item.metaId, type: item.metaType, name: item.title, poster: item.HDPosterUrl } }
end function

' Moves focus between a keyboard and the button under it. Returns true when the key was handled.
' Gives the keys to the screen's own onKeyEvent (see the "keys" node in Screen.xml).
sub Ui_parkFocus(screen as object)
    screen.findNode("keys").setFocus(true)
end sub

function Ui_keyboardNav(key as string, keyboard as object, button as object) as boolean
    if key = "down" and keyboard.isInFocusChain()
        button.setFocus(true)
        return true
    end if
    if key = "up" and button.hasFocus()
        keyboard.setFocus(true)
        return true
    end if
    return false
end function

' Empty tiles: the grey tile background shows while the row loads.
sub Ui_placeholder(row as object, count as integer)
    row.removeChildrenIndex(row.getChildCount(), 0)
    for i = 1 to count
        row.createChild("ContentNode")
    end for
end sub

function Ui_childById(parent as object, id as string) as dynamic
    for i = 0 to parent.getChildCount() - 1
        child = parent.getChild(i)
        if child.id = id then return child
    end for
    return invalid
end function

' Small labelled boxes in a row; returns where the row ends. Recycled list items call this on every scroll,
' so the boxes already in parent (a box and its label per text) are reused and the spare ones hidden.
function Ui_pills(parent as object, texts as object, x as integer, y as integer) as integer
    for i = 0 to texts.Count() - 1
        if parent.getChildCount() < (i + 1) * 2
            pill = parent.createChild("Rectangle")
            pill.color = "0xFFFFFF1F"
            pill.height = 30
            label = parent.createChild("Label")
            label.font = "font:SmallestSystemFont"
            label.color = "0xE6E6E6FF"
        end if
        pill = parent.getChild(i * 2)
        label = parent.getChild(i * 2 + 1)
        pill.visible = true
        label.visible = true
        pill.translation = [x, y]
        label.text = texts[i]
        label.translation = [x + 10, y + 3]
        w = label.boundingRect().width + 20
        pill.width = w
        x = x + w + 12
    end for
    for i = texts.Count() * 2 to parent.getChildCount() - 1
        parent.getChild(i).visible = false
    end for
    return x
end function
