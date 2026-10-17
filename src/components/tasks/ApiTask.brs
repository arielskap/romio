sub init()
    m.top.functionName = "runOp"
end sub

sub runOp()
    op = m.top.op
    result = Flows_run(op, m.top.args)
    if not result.ok then print "[ApiTask] "; op; " failed: "; result.error
    m.top.result = result
end sub
