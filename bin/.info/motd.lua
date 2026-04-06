return {
    help=[[
    displays "The Moto Of The Day" or just a random message
    you can select the motd index in the second argument (planning to add -C
    to list motd count)
    example:
    motd]],
    completion = {
        variableArgs = false,
        nargs = 1,
        arg={
            {
                type="number",
                lowerlimit = -math.huge,
                upperlimit = math.huge
            }
        }
    }
}