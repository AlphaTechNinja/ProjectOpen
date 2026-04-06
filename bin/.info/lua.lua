return {
    help=[[
    runs a lua file or enters into the interactive
    console (if no args are passed)
    example:
    lua <file>.lua]],
    completion = {
        variableArgs = true,
        arg={
            type="file",
            path="$CWD"
        }
    }
}