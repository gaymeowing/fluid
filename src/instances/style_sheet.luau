local action = require("./action")
local cleanup = require("../reactive/cleanup")
local graph = require("../reactive/graph")
local instance_types = require("./types")
local tags = require("../utils/tags")

type Action = action.Identity
type Instances = instance_types.Instances
type RobloxStyleSheet = StyleSheet
type RobloxGuiObject = GuiObject
type RobloxInstance = Instance
type RobloxTweenInfo = TweenInfo
type RobloxSignal = RBXScriptSignal
type RobloxStyleQuery = StyleQuery

type RuntimeSheet = { read instance: RobloxStyleSheet }

-- `::StyleQuery` pseudo-instances take their conditions as properties
type QueryConditions = {
	AspectRatioRange: NumberRange,
	MaxSize: Vector2,
	MinSize: Vector2,
	PreferredInput: Enum.PreferredInput,
	PreferredTextSize: Enum.PreferredTextSize,
	ReducedMotionEnabled: boolean,
	ViewportDisplaySize: Enum.DisplaySize,
}

type BuiltInQueries = {
	PreferredInputKeyboardAndMouse: true,
	PreferredInputGamepad: true,
	PreferredInputTouch: true,
	PreferredInputMicroGamepad: true,
	ViewportDisplaySizeSmall: true,
	ViewportDisplaySizeMedium: true,
	ViewportDisplaySizeLarge: true,
	PreferredTextSizeMedium: true,
	PreferredTextSizeLarge: true,
	PreferredTextSizeLarger: true,
	PreferredTextSizeLargest: true,
	ReducedMotionEnabledTrue: true,
	ReducedMotionEnabledFalse: true,
}

type Props = {
	_transitions: { [string]: TweenInfo | string }?,
	_queries: { [string]: Props }?,
	_priority: number?,
	[string | number]: PseudoInstance | any,
}

export type PseudoInstance = {
	read selector: string,
	read props: Props,
}

type function VALIDATE_STRINGLETON(s: type, string_type: string): type
	if not (s.tag == "singleton" and type(s:value()) == "string") then
		error(`{string_type} provided is not a string singleton`, 2)
	elseif s:value() == "" then
		error(`{string_type} provided can't be an empty string singleton`, 2)
	end
	return s
end

type function Merge(base: type, overrides: type): type
	local properties = {} :: { [type]: type }
	local keys = {} :: { [string]: type }
	local source = base

	for index = 1, 2 do
		for key, property in source:properties() do
			local name = key:value() :: string
			local previous = keys[name]

			if previous then
				properties[previous] = nil
			end

			properties[key] = property.read
			keys[name] = key
		end
		source = overrides
	end

	return types.newtable(properties, overrides:indexer() or source:indexer())
end

type function TokenRefs(tokens: type): { [string]: type }
	local refs = {} :: { [string]: type }

	for key, property in tokens:properties() do
		local token_type = property.read
		if token_type then
			-- equal types aren't the same userdata, so types are keyed by what tostring gives for them
			local type_name = tostring(token_type)
			local reference = types.singleton("$" .. (key:value() :: string))
			local existing = refs[type_name]
			refs[type_name] = if existing then types.unionof(existing, reference) else reference
		end
	end

	local indexer = tokens:indexer()
	if indexer then
		refs[tostring(indexer.readresult)] = types.string
	end

	return refs
end

type function StyleValue(value: type, refs: { [string]: type }): type
	local value_refs = refs[tostring(value)]
	return types.optional(if value_refs then types.unionof(value, value_refs) else value)
end

type function SelectorInstances(selector: type): { type }
	local instances = {} :: { type }

	for part in string.gmatch(selector:value() :: string, "[^,]+") do
		-- Only the compound after the last `>` / `>>` combinator gets styled.
		local compound = string.match(part, "[^>]*$") :: string
		local class_name = string.match(compound, "^%s*([%a_][%w_]*)")

		for pseudo_instance in string.gmatch(compound, "::%s*([%a_][%w_]*)") do
			class_name = pseudo_instance
		end

		local instance = if class_name then Instances:readproperty(types.singleton(class_name)) else nil
		table.insert(instances, instance or RobloxGuiObject)
	end

	return if #instances > 0 then instances else { RobloxGuiObject }
end

type function StyleProperties(selector: type, tokens: type, queries: type): type
	local selector_value = VALIDATE_STRINGLETON(selector, "selector"):value() :: string
	-- TODO: when luau allows use instance_types.get_read_only_properties so this table doesnt have to exist in 2 places
	local read_only_properties = table.freeze({
		types.singleton("RobloxLocked"),
		types.singleton("ClassName"),
		types.singleton("UniqueId"),
	})

	-- every query that `@Name` selectors and `_queries` can use
	local query_keys = {} :: { [string]: type }
	local source = BuiltInQueries
	for i = 1, 2 do
		for key in source:properties() do
			query_keys[key:value() :: string] = key
		end
		source = queries
	end

	for name in string.gmatch(selector_value, "@([%w_%-]+)") do
		if not query_keys[name] then
			error(`unknown query @{name}, add it with :query()`)
		end
	end

	-- rules can't reference instances, so Parent and other instance properties are left out.
	local instance_value = types.optional(RobloxInstance)
	local instance_values = {} :: { [string]: boolean }
	-- selector lists merge properties by name
	local keys = {} :: { [string]: type }
	local values = {} :: { [string]: type }

	local function add(property: type, value: type)
		local name = property:value() :: string
		local previous = values[name]
		if not previous then
			keys[name] = property
			values[name] = value
		elseif previous ~= value then
			values[name] = types.intersectionof(previous, value)
		end
	end

	for _, instance in SelectorInstances(selector) do
		if instance == RobloxStyleQuery then
			for property, condition in QueryConditions:properties() do
				add(property, condition.read :: type)
			end
		end

		local current: type? = instance

		while current do
			for property, value in current:properties() do
				local value_write = value.write
				local value_read = value.read

				if
					not value_read
					or not value_write
					or value_read.tag == "function"
					or value_read.tag == "intersection"
					or value_read == RobloxSignal
					or table.find(read_only_properties, property)
				then
					continue
				end

				-- ignoring luau-lsp RBXScriptSignals, because luau-lsp uses table types for RBXScriptSignals
				if value_read:is("table") then
					local connect = value_read:readproperty(types.singleton("Connect"))
					if connect and connect:is("function") then
						continue
					end
				end

				local value_name = tostring(value_write)
				local is_instance = instance_values[value_name]

				if is_instance == nil then
					is_instance = value_write:issubtypeof(instance_value)
					instance_values[value_name] = is_instance
				end

				if not is_instance then
					add(property, value_write)
				end
			end

			current = current:readparent()
		end
	end

	local refs = TokenRefs(tokens)
	local transition = StyleValue(RobloxTweenInfo, refs)
	local transitions = {}
	local style = {}

	for name, key in keys do
		style[key] = StyleValue(values[name], refs)
		transitions[key] = transition
	end

	transitions[types.singleton("_default")] = transition
	style[types.singleton("_priority")] = types.optional(types.number)
	style[types.singleton("_transitions")] = types.optional(types.newtable(transitions))

	-- pseudo-instances go in the array part, like instance children in the props table of fluid.bind
	local props =
		types.newtable(style, { index = types.number, readresult = PseudoInstance, writeresult = PseudoInstance })

	-- `_queries` has a key for every query, holding the props of a nested `@Name` rule that applies while the
	-- query is active. A nested rule takes the same props as this one, `_queries` included, so the props table
	-- has to exist before `_queries` can point back at it.
	local query_rule = types.optional(props)
	local query_rules = {} :: { [type]: type }

	for _, key in query_keys do
		query_rules[key] = query_rule
	end

	props:setproperty(types.singleton("_queries"), types.optional(types.newtable(query_rules)))
	return props
end

type function QueryConditionValues(tokens: type): type
	local refs = TokenRefs(tokens)
	local conditions = {}

	for key, condition in QueryConditions:properties() do
		conditions[key] = StyleValue(condition.read :: type, refs)
	end
	return types.newtable(conditions)
end

type function TagsFrom(selector: type): type
	selector = VALIDATE_STRINGLETON(selector, "selector")
	local true_singleton = types.singleton(true)
	local tags = {} :: { [type]: type }

	for name in string.gmatch(selector:value() :: string, "%.([%w_%-]+)") do
		tags[types.singleton(name)] = true_singleton
	end
	return types.newtable(tags)
end

type function QueryFrom(name: type): type
	name = VALIDATE_STRINGLETON(name, "query name")
	return types.newtable({ [name] = types.singleton(true) })
end

type function PseudoSelector(selector: type): type
	selector = VALIDATE_STRINGLETON(selector, "pseudo-instance selector")
	return types.singleton("::" .. (selector:value() :: string))
end

type SheetData<Tokens, Tags, Queries> = {
	read instance: RobloxStyleSheet,
	read __I_DO_NOT_EXIST_AT_RUNTIME: {
		read queries: Queries,
		read tokens: Tokens,
		read tags: Tags,
	},
}

type TypeOnly<Self> = index<Self, "__I_DO_NOT_EXIST_AT_RUNTIME">
type TokensOf<Self> = index<TypeOnly<Self>, "tokens">
type TagsOf<Self> = index<TypeOnly<Self>, "tags">
type QueriesOf<Self> = index<TypeOnly<Self>, "queries">
type TagValue<Self> = keyof<TagsOf<Self>> | () -> keyof<TagsOf<Self>>?

type TokenState<Self, NewTokens> = SheetData<Merge<TokensOf<Self>, NewTokens>, TagsOf<Self>, QueriesOf<Self>>
type QueryState<Self, Name> = SheetData<TokensOf<Self>, TagsOf<Self>, Merge<QueriesOf<Self>, QueryFrom<Name>>>
type DerivedState<Self, Other> = SheetData<
	Merge<TokensOf<Other>, TokensOf<Self>>,
	Merge<TagsOf<Self>, TagsOf<Other>>,
	Merge<QueriesOf<Self>, QueriesOf<Other>>
>
type RuleState<Self, Selector> = SheetData<TokensOf<Self>, Merge<TagsOf<Self>, TagsFrom<Selector>>, QueriesOf<Self>>

-- string generics are unioned with "" because otherwise luau widens them to `string`,
type SheetPrototype = {
	__index: SheetPrototype,
	tags: <Self>(self: Self, tags: { TagValue<Self> }) -> Action,
	link: (self: RuntimeSheet) -> Action,
	tokens: <Self, NewTokens>(
		self: Self,
		tokens: NewTokens
	) -> setmetatable<TokenState<Self, NewTokens>, SheetPrototype>,
	query: <Self, Name>(
		self: Self,
		name: Name | ""
	) -> (QueryConditionValues<TokensOf<Self>>) -> setmetatable<QueryState<Self, Name>, SheetPrototype>,
	derive: <Self, Other>(self: Self, from: Other) -> setmetatable<DerivedState<Self, Other>, SheetPrototype>,
	underive: <Self>(self: Self, from: RuntimeSheet) -> Self,
	pseudo: <Self, Selector>(
		self: Self,
		selector: Selector | ""
	) -> (StyleProperties<PseudoSelector<Selector>, TokensOf<Self>, QueriesOf<Self>>) -> PseudoInstance,
	rule: <Self, Selector>(
		self: Self,
		selector: Selector | ""
	) -> (
		StyleProperties<Selector, TokensOf<Self>, QueriesOf<Self>>
	) -> setmetatable<RuleState<Self, Selector>, SheetPrototype>,
}

export type Sheet<Tokens = {}, Tags = {}, Queries = {}> = setmetatable<SheetData<Tokens, Tags, Queries>, SheetPrototype>

local function create_rule(parent: Instance, selector: string, props: Props, name: string?)
	local rule = Instance.new("StyleRule")
	rule.Selector = selector
	rule.Name = name or selector

	local priority = props._priority
	if priority then
		rule.Priority = priority
		props._priority = nil
	end

	local transitions = props._transitions
	if transitions then
		for property, transition in transitions do
			if property == "_default" then
				rule:SetDefaultPropertyTransition(transition)
			else
				rule:SetPropertyTransition(property, transition)
			end
		end
		props._transitions = nil
	end

	local queries = props._queries
	if queries then
		for name, query_props in queries do
			create_rule(rule, "@" .. name, query_props)
		end
		props._queries = nil
	end

	for i = #props, 1, -1 do
		local pseudo_instance = props[i] :: PseudoInstance
		create_rule(rule, pseudo_instance.selector, pseudo_instance.props)
		props[i] = nil
	end

	rule:SetProperties(props)
	rule.Parent = parent
end

local style_sheet_prototype = {}
style_sheet_prototype.__index = style_sheet_prototype

function style_sheet_prototype.tags(_self: RuntimeSheet, selected_tags: { string | () -> string? })
	return tags(selected_tags)
end

function style_sheet_prototype.tokens(self: RuntimeSheet, tokens: { [string]: unknown })
	local instance = self.instance

	for token_name, value in tokens do
		instance:SetAttribute(token_name, value)
	end
	return self
end

function style_sheet_prototype.rule(self: RuntimeSheet, selector: string)
	return function(props: Props)
		create_rule(self.instance, selector, props)
		return self
	end
end

function style_sheet_prototype.pseudo(_self: RuntimeSheet, selector: string)
	return function(props: Props): PseudoInstance
		return table.freeze({ selector = "::" .. selector, props = props })
	end
end

-- TODO: optimize this in future if this ever becomes an issue, via making global queries be applied only to rules that use them
-- rather than just having them be a rule that applies to any GuiObject
function style_sheet_prototype.query(self: RuntimeSheet, name: string)
	return function(conditions: Props)
		-- a StyleQuery only activates under the instance it checks, so every GuiObject gets it as a pseudo-instance
		-- because its the easiest way to do a global style query
		-- #{name} is what names that pseudo-instance so @{name} selectors match it
		create_rule(self.instance, `GuiObject::StyleQuery #{name}`, conditions, name)
		return self
	end
end

function style_sheet_prototype.derive(self: RuntimeSheet, other: RuntimeSheet)
	local instance = self.instance
	local derives = instance:GetDerives()
	table.insert(derives, other.instance)
	instance:SetDerives(derives)
	return self
end

function style_sheet_prototype.underive(self: RuntimeSheet, other: RuntimeSheet)
	local instance = self.instance
	local derives = instance:GetDerives()
	local index = table.find(derives, other.instance)
	local total_derives = #derives

	if index then
		derives[index], derives[total_derives] = derives[total_derives], nil
		instance:SetDerives(derives)
	end
	return self
end

function style_sheet_prototype.link(self: RuntimeSheet)
	return action.create(function(instance)
		graph.assert_scope()
		local link = Instance.new("StyleLink")
		link.StyleSheet = self.instance
		link.Parent = instance
		cleanup(link)
	end)
end

local function style_sheet(name: string, parent: Instance): Sheet<{}, {}, {}>
	local instance = Instance.new("StyleSheet")
	instance.Name = name

	-- deferring parenting as to avoid datamodel change tracking whilst the style sheet is being built
	task.defer(function(instance: Instance, parent: Instance)
		instance.Parent = parent
	end, instance, parent)

	return table.freeze(setmetatable({
		instance = instance,
	}, style_sheet_prototype)) :: any
end

table.freeze(style_sheet_prototype)
return style_sheet
