type OkResult<T> = {
	success: true,
	value: T,
}

type FailResult<T> = {
	success: false,
	err: T,
	trace: string,
}

export type Identity<T, E> = OkResult<T> | FailResult<E>

local function ok<T>(value: T): OkResult<T>
	return {
		success = true :: true,
		value = value :: T,
	}
end

local function fail<T>(value: T, trace: string): FailResult<T>
	return {
		success = false :: false,
		err = value,
		trace = trace,
	}
end

local function call<OK, T...>(fn: (T...) -> OK, ...: T...): Identity<OK, unknown>
	local success, value: any = xpcall(fn, function(err: string)
		local message = string.gsub(tostring(err), "^.+:%d+:%s*", "")
		local trace = debug.traceback(nil, 2)

		return {
			message = message,
			trace = trace,
		}
	end, ...)

	if not success then
		return fail(value.message, value.trace)
	else
		return ok(value)
	end
end

return {
	call = call,
	fail = fail,
	ok = ok,
}
