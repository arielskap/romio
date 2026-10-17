' What MainScene shows while the intro animation and boot run in parallel:
' "wait" keeps the intro on screen, "skeleton" covers a boot slower than the intro, "go" shows the result.
function Intro_step(animDone as boolean, bootDone as boolean) as string
    if not animDone then return "wait"
    if bootDone then return "go"
    return "skeleton"
end function
