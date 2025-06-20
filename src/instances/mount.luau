local bind = require("./bind")
local root = require("../reactive/root")

local function mount(fn: () -> { [any]: any }, inst: Instance): () -> ()
	return root(function()
		bind(fn(), inst)
	end)
end

return mount
