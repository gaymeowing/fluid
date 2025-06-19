local logging = require("../logging")
local types = require("./types")

export type SourceNode<T> = {
	last_evaluation: number,

	read state: "clean",
	read effect: false,

	cached_value: T,

	--- Other nodes that depend on the result of this node.
	read dependents: { ReactiveNode<T> },
}

export type StableNode<T> = {
	read parent: Node<T> | false,
	read children: { Node<T> },

	--- Describes the effect to run to compute the result of this node.
	read effect: false,

	read state: "clean",
	read last_evaluation: number,

	read cached_value: T,

	-- Cleanup functions run when the node dies
	read cleanups: { () -> () },
}

export type ReactiveNode<T> = {
	read parent: Node<T> | false,
	read children: { Node<T> },

	--- Describes the effect to run to compute the result of this node.
	read effect: types.Effect<T>,
	read evaluation: "eager" | "deferred" | "lazy" | "dead",
	last_evaluation: number,

	-- clean: the cached_value result can be used immediately
	-- dirty: you need to recompute the node
	-- busy: the node is already being recomputed - throw an error!
	-- dead: the node is dead
	state: "clean" | "dirty" | "busy" | "dead",

	cached_value: T,

	read cleanups: { () -> () } | false,

	depending_on: { SourceNode<T> | ReactiveNode<T> },
	read dependents: { ReactiveNode<T> },
}

export type Node<T> = ReactiveNode<T> | StableNode<T>

local processing_node: Node<unknown> | false = false
local deferred_nodes = {}
local version = 0

local function bump_version()
	--print("bump version")
	version += 1
	return version
end

type Result<OK, ERR = string> = {
	ok: true,
	value: OK,
} | {
	ok: false,
	err: ERR,
	trace: string,
}

-- * Result addendum
local _result = { ok = false, value = nil, err = nil }
local _result_mt = {
	__tostring = function(self)
		return `{self.err}\ntrace: {self.trace}`
	end,
}

setmetatable(_result, _result_mt)

local function ok_result<OK>(value: OK): { ok: true, value: OK }
	-- local _result = setmetatable({}, _result_mt)
	_result.ok = true
	_result.value = value
	return _result :: any
end

local function fail_result<ERR>(
	value: ERR,
	trace: string
): { ok: false, err: ERR, trace: string }
	local _result = setmetatable({}, _result_mt)
	_result.ok = false
	_result.err = value
	_result.trace = trace
	return _result :: any
end

local function get_result<OK, T...>(fn: (T...) -> OK, ...: T...): Result<OK, unknown>
	local ok, value: any = xpcall(fn, function(err: string)
		local message = string.gsub(tostring(err), "^.+:%d+:%s*", "")
		local trace = debug.traceback(nil, 2)
		return {
			message = message,
			trace = trace,
		}
	end, ...)
	if not ok then
		return fail_result(value.message, value.trace)
	else
		return ok_result(value)
	end
end
-- *

local function run_as_unsafe<T, U...>(
	owner: Node<any> | false,
	fn: (U...) -> T,
	...: U...
): Result<T, unknown>
	local previous_processing = processing_node
	processing_node = owner
	local result = fn(...)
	processing_node = previous_processing
	return result
end

local function defer_node<T>(node: ReactiveNode<T>)
	if node.state == "dirty" then
		return
	end
	node.state = "dirty" :: any
	table.insert(deferred_nodes, node)
end

local function push_dependency<T>(node: SourceNode<T> | ReactiveNode<T>)
	if processing_node and processing_node.effect then
		if processing_node == node then
			error(
				`cannot add itself as dependency {node.effect}, {processing_node.effect}`
			)
		end
		table.insert(node.dependents, processing_node)
		table.insert(processing_node.depending_on, node)
	end
end

local function find_and_swap_pop<T>(t: { T }, v: T)
	local i = table.find(t, v) :: number
	local n = #t
	t[i] = t[n]
	t[n] = nil
end

local function flush_cleanups<T>(node: Node<T>)
	-- if node.effect and flags.strict then print(debug.traceback()) end
	if node.cleanups then
		for _, fn in node.cleanups do
			local result = get_result(fn)
			if not result.ok then
				error(`cleanup error: {result.err}`, 0)
			end
		end

		table.clear(node.cleanups)
	end
end

local function remove_dependencies<T>(node: Node<T>)
	if node.effect then
		for idx, dependency in node.depending_on do
			find_and_swap_pop(dependency.dependents, node)
		end
		table.clear(node.depending_on)
	end
end

local function destroy<T>(node: Node<T>)
	-- node.cached_value = nil
	flush_cleanups(node)
	remove_dependencies(node)

	if node.parent then
		find_and_swap_pop(node.parent.children, node)
		-- TODO: Luau type state issue
		node.parent = false :: any
	end

	while node.children[1] do
		destroy(node.children[1])
	end
end

local function destroy_owned<T>(node: Node<T>)
	for _, node: Node<T> in node.children do
		destroy(node)
	end
	table.clear(node.children)
end

local function is_similar(a: unknown, b: unknown): boolean
	local both_are_tables = type(a) == "table"
		and type(b) == "table"
		and not table.isfrozen(a :: any)
		and not table.isfrozen(b :: any)

	return if both_are_tables then false else a == b
end

local function update_node<T>(node: ReactiveNode<T>): Result<T>
	local previous_result = node.cached_value
	local previous_processing = processing_node

	flush_cleanups(node)
	destroy_owned(node)
	remove_dependencies(node)

	-- print("rerunning", debug.info(node.effect, "n"), previous_result, node)

	processing_node = node
	local result = get_result(node.effect, previous_result)
	processing_node = previous_processing

	if result.ok then
		node.state = "clean" :: any --fixme: typechecking bug
		push_dependency(node)

		if
			node.evaluation ~= "eager"
			and is_similar(previous_result, result.value)
		then
			-- print("DID NOT UPDATE BECAUSE SIMILAR AT", debug.info(node.effect, "sl"))
			return ok_result(node.cached_value)
		end
		-- print("UPDATE BECAUSE NOT SIMILAR AT", debug.info(node.effect, "sl"))

		node.last_evaluation = bump_version()
		node.cached_value = result.value

		return ok_result(node.cached_value)
	else
		logging.warn(`effect error: {result}`)
		return fail_result(`effect error: {result.err}`, result.trace)
	end
end

local function is_dirty<T>(node: ReactiveNode<T>)
	local last_evaluation = node.last_evaluation

	if node.state == "clean" then
		return false
	end

	for _, dependency in node.depending_on do
		-- if a dependent was evaluated after this node was evaluated, it's dirty
		if dependency.effect and dependency.state == "dirty" then
			-- make sure the dependency isn't dirty
			update_node(dependency :: ReactiveNode<T>)
		end

		if dependency.last_evaluation > last_evaluation then
			return true
		end
	end

	return #node.depending_on == 0
end

local function evaluate_node<T>(node: SourceNode<T> | ReactiveNode<T>): Result<T>
	if node.effect == false or node.state == "clean" then
		push_dependency(node :: SourceNode<T> | ReactiveNode<T>)

		return ok_result(node.cached_value)
	elseif node.state == "busy" then
		return fail_result(
			`this creates a recursive dependency, which can result in creating a infinite loop.`,
			debug.traceback(nil, 2)
		)
	elseif node.state == "dead" then
		return ok_result(node.cached_value)
	elseif is_dirty(node :: ReactiveNode<T>) then
		return update_node(node :: ReactiveNode<T>)
	else
		node.state = "clean" :: any
		return ok_result(node.cached_value)
	end
end

local _pending_eval: { ReactiveNode<unknown> } = {}
local function invalidate_loop<T>(node: SourceNode<T> | ReactiveNode<T>)
	if node.state == "dirty" then
		return
	end

	for _, value in node.dependents do
		if value.evaluation == "eager" then -- append it to a queue so it can be evaluated after all nodes are marked dirty.
			invalidate_loop(value)

			value.state = "dirty"
			table.insert(_pending_eval, value)
		elseif value.evaluation == "deferred" then
			invalidate_loop(value)

			defer_node(value)
		else
			invalidate_loop(value)

			value.state = "dirty"
		end
	end
end

local function invalidate<T>(node: SourceNode<T>)
	invalidate_loop(node)

	for _, node in _pending_eval do
		-- print("CHECKING", count(node.depending_on), "DEPENDENCIES FOR", debug.info(node.effect, "sl"))
		for _, dependent in node.depending_on do
			-- print("CHECKING", dependent.last_evaluation > node.last_evaluation, dependent.effect and `{debug.info(dependent.effect, "s")}:{debug.info(dependent.effect, "l")}`)
			run_as_unsafe(false, evaluate_node, dependent)
			-- print("checked", dependent.state, dependent.last_evaluation > node.last_evaluation, `{debug.info(dependent.effect, "s")}:{debug.info(dependent.effect, "l")}`)
		end

		-- print("EVALUATING NODE", is_dirty(node))
		run_as_unsafe(false, evaluate_node, node)
	end
	table.clear(_pending_eval)
end

local graph = {
	-- re-exports of local utilities
	invalidate = invalidate,
	destroy = destroy,
	run_as_unsafe = run_as_unsafe,
	push_dependency = push_dependency,
	evaluate_node = evaluate_node,
}

function graph.flush_deferred_nodes()
	for _, node in deferred_nodes do
		local result = evaluate_node(node)

		if result.ok == false then
			warn(`deferred node error: {result}`)
		end
	end

	table.clear(deferred_nodes)
end

function graph.create_reactive_node<T>(
	parent: StableNode<T> | false,
	effect: types.Effect<T>,
	evaluation: "eager" | "deferred" | "lazy",
	cached_value: T?
)
	local node: ReactiveNode<T> = {
		parent = parent,
		last_evaluation = bump_version(),

		effect = effect,
		evaluation = evaluation,
		state = "dirty",
		cached_value = cached_value,
		depending_on = {},
		dependents = {},

		children = {} :: { Node<T> },
		cleanups = {},
	}

	if parent then
		table.insert(parent.children, node)
	end

	if evaluation == "deferred" then
		table.insert(deferred_nodes, node)
	end

	return node
end

function graph.create_stable_node<T>(parent: Node<T> | false)
	local node: StableNode<T> = {
		parent = parent,

		effect = false,
		state = "clean",
		last_evaluation = bump_version(),

		cached_value = nil,

		children = {},
		cleanups = {},
	}

	if parent then
		table.insert(parent.children, node)
	end

	return node
end

function graph.create_source_node<T>(value: T): SourceNode<T>
	local node: SourceNode<T> = {
		last_evaluation = bump_version(),
		effect = false,
		cached_value = value,
		state = "clean",
		dependents = {},
	}

	return node
end

function graph.update_source_node<T>(node: SourceNode<T>, value: T)
	if is_similar(node.cached_value, value) then
		return
	end
	node.last_evaluation = bump_version()
	node.cached_value = value
	invalidate(node)
end

function graph.get_scope<T>(): Node<T> | false
	return processing_node
end

function graph.push_cleanup<T>(scope: Node<T>, cleanup: () -> ())
	if scope.cleanups == false then
		scope.cleanups = { cleanup } :: any --fixme: type error
	else
		table.insert(scope.cleanups, cleanup)
	end
end

function graph.run_as<T, U...>(
	owner: Node<any> | false,
	fn: (U...) -> T,
	...: U...
): Result<T, unknown>
	local previous_processing = processing_node
	processing_node = owner
	local result = get_result(fn, ...)
	processing_node = previous_processing
	return result
end

function graph.assert_stable_parent<T>(): StableNode<T>
	if not processing_node then
		error(`cannot call {debug.info(2, "n")} without a parent scope`, 2)
	elseif processing_node.effect ~= false then
		error(
			`cannot call {debug.info(2, "n")} while the parent scope is reactive - this might be a component. consider using untrack() while creating the components.`,
			2
		)
	end

	return processing_node :: StableNode<T>
end

return graph
