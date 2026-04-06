return {
    help=[[
    lists the provided files/folders in the current working directory
    if no path is specified else it resolves the input path then lists
    it's contents
    example:
    ls /bin/]],
    completion = {
        variableArgs = false,
        nargs=1,
        arg={
            {
                type="directory",
                path="$CWD"
            }
        }
    }
}