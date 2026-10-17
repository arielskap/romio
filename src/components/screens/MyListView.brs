sub init()
    m.top.focusable = true
    m.filter = m.top.findNode("filter")
    m.grid = m.top.findNode("grid")
    m.empty = m.top.findNode("empty")
    m.kind = ""
    m.items = []
    m.filter.items = ["Todo", "Películas", "Series"]
    m.filter.observeField("chosen", "onFilter")
    m.grid.observeField("itemSelected", "onSelected")
    m.top.observeField("focusedChild", "onFocus")
end sub

' Focus given to the view itself goes to the grid, or to the filter when there is nothing to show.
sub onFocus()
    if not m.top.hasFocus() then return
    if m.items.Count() > 0 then m.grid.setFocus(true) else m.filter.setFocus(true)
end sub

sub onFilter()
    kinds = ["", "movie", "series"]
    m.filter.selected = m.filter.chosen
    m.kind = kinds[m.filter.chosen]
    fill()
end sub

sub fill()
    if m.top.library = invalid then return
    m.items = Library_myList(m.top.library, m.kind)
    root = CreateObject("roSGNode", "ContentNode")
    for each it in m.items
        Ui_fillLibraryItem(root.createChild("ContentNode"), it, false)
    end for
    m.grid.content = root
    m.grid.visible = m.items.Count() > 0
    m.empty.visible = m.items.Count() = 0
    if not m.top.libraryLoaded
        m.empty.text = "No se pudo cargar tu biblioteca de Stremio."
    else
        m.empty.text = "Todavía no guardaste nada. Lo que agregues a tu biblioteca en Stremio aparece acá."
    end if
end sub

sub onSelected()
    it = m.items[m.grid.itemSelected]
    if it <> invalid then m.top.selectedItem = it
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "up" and m.grid.hasFocus()
        m.filter.setFocus(true)
        return true
    end if
    if key = "down" and m.filter.isInFocusChain() and m.items.Count() > 0
        m.grid.setFocus(true)
        return true
    end if
    return false
end function
