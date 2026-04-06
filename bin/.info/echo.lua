return {
    help=[[
    prints whatever is inputed as arguments
    example:
    echo Hello, World!]],
    completion = {
        variableArgs = true,
        arg={
            type="variable"
        }
    }
}