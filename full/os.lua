-- adds my os features
local os = ...
os.version = "ProjectOpen 1.0"
os.driversEnabled = true -- incase i make a fork os that is the same but a light version without drivers
os.shellVersion = "1.0"
os.supportsBash = false -- not implemented
os.execute = require("simpleshell").execute
