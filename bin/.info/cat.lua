-- returns a valid info object for cat
-- this is the first info object and it provides information to help and auto completeion
return {
    help=[[
    prints the contents of the provided folders in order
    cat will error if it is passed a non-existant path 
    or feed a directory plans to allow \n to be treated as whitespace
    from piping from ls
    example:
    cat /bin/cat.lua]],
    completion = {
        variableArgs = true,
        args = {
            -- this has the same meaning as ... in  function
            type="file",
            path="$CWD"
        }
    }
}