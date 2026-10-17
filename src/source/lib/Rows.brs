' Where the home focus goes back to after the "Continuar viendo" row (row 0) was refreshed.
' focused is [row, column]; the continue row may have appeared, disappeared or reordered.
' focusedId is the title that had focus; rowIds are the refreshed continue row's titles, in order.
function Rows_shiftFocus(focused as object, hadContinue as boolean, hasContinue as boolean, focusedId as string, rowIds as object) as object
    row = focused[0]
    col = focused[1]
    if hadContinue and hasContinue and row = 0
        ' A title just watched moves to the front: follow it. One that left the row keeps the column.
        for i = 0 to rowIds.Count() - 1
            if rowIds[i] = focusedId then return [0, i]
        end for
        if col > rowIds.Count() - 1 then col = rowIds.Count() - 1
        if col < 0 then col = 0
        return [0, col]
    end if
    if hadContinue and row = 0 then return [0, 0]
    if hasContinue and not hadContinue then row = row + 1
    if hadContinue and not hasContinue then row = row - 1
    if row < 0 then row = 0
    return [row, col]
end function
