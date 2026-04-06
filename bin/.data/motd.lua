-- stores all the motd
return {
    ("welcome to Project open shell v%s\n"):format(os.shellVersion),
    function (shell)
        -- hehe funny beep
        computer.beep(math.random(100,2000))
        return "here is a random beep for you\n"
    end
}