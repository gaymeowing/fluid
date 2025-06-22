local process = require("@lune/process")

process.exec(
	"rojo",
	{ "build", "roblox-tests.project.json", "--output", "test-file.rbxl" },
	{ stdio = "forward" }
)
