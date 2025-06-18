local process = require("@lune/process")

process.exec(
	"rojo",
	{ "build", "--output", "liquid.rbxm" },
	{ stdio = "forward" }
)
