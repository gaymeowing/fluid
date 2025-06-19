--!optimize 1
local colorful = require("./vendor/colorful")

local dev_mode = _G.__DEV__ == true

local function format(text: string): string
	return (string.format("[fluid]: %*", text))
end

local function use_traceback(text: string): string
	return (debug.traceback(format(text), 3))
end

local function warn_facade(text: string)
	if warn then
		warn(text)
		return
	end

	print(colorful.color.yellowBright(text))
end

local logging = {}

function logging.trace(text: string, traceback: boolean?)
	if traceback == nil then
		traceback = dev_mode
	end

	if dev_mode then
		print(if traceback then use_traceback(text) else format(text))
	end
end

function logging.warn(text: string, traceback: boolean?)
	if traceback == nil then
		traceback = dev_mode
	end

	warn_facade(if traceback then use_traceback(text) else format(text))
end

return logging
