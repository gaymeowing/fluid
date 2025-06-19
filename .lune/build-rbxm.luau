local process = require("@lune/process")

process.exec(
	"rojo",
	{ "build", "--output", "fluid.rbxm" },
	{ stdio = "forward" }
)
