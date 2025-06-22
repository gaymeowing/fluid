local bind = require("./bind")
local root = require("../reactive/root")

local function mount(fn: () -> { [any]: any }, inst: Instance): () -> ()
	return root(function()
		bind(inst, {
			fn(),
		})
	end)
end

return mount
