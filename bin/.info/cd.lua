return {
    help=[[
    moves the current working directory to the specified folder
    within the current working directory (use .. to move out 1 folder)
    example:
    cd $HOME]],
    completion = {
        variableArgs = false,
        nargs = 1,
        arg = {
            {
                type = "directory",
                path = "$CWD"
            }
        }
    }
}