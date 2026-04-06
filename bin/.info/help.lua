return {
    help=[[
    displays help information for a given program
    pass -a as the argument to list avaiable docs
    example:
    help help]],
    completion = {
        variableArgs = false,
        nargs = 1,
        arg = {
            {
                type="program", -- special should try to complete both programs from $PROG/ and tha aliases
                progbin="$PROG"
            }
        }
    }
}