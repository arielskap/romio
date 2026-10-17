' Tile content from a Stremio library item. Needs Library, Art, Format and Meta in the component's scope.
sub Ui_fillLibraryItem(node as object, item as object, landscape as boolean)
    progress = Library_progress(item)
    subtitle = ""
    if progress > 0 then subtitle = Library_continueLabel(item)
    node.addFields({ metaId: item._id, metaType: item.type, subtitle: subtitle, landscape: landscape, progress: progress, finished: Library_isFinished(item) })
    node.title = item.name
    if landscape
        node.HDPosterUrl = Art_background(item._id, Library_str(item.background))
    else
        node.HDPosterUrl = Art_resize(Library_str(item.poster), 500)
    end if
end sub
