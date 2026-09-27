local action = require("./action")
local cleanup = require("../reactive/cleanup")
local graph = require("../reactive/graph")
local tags = require("../utils/tags")
local instance_types = require("./types")

export type Transitions = {
	Default: TweenInfo?,
	[string]: TweenInfo,
}

type Action = action.Identity
-- Do not name anything `StyleSheet` in this file — it late-binds over Roblox's extern.
type RobloxStyleSheet = StyleSheet
type RobloxGuiObject = GuiObject
type RobloxTweenInfo = TweenInfo
type RobloxSignal = RBXScriptSignal
type RobloxStyleQuery = StyleQuery



type function WritableProperties(class_type: type): type
	local properties = types.newtable()
	local current: type? = class_type
	local read_only_properties = table.freeze({
		types.singleton("RobloxLocked"),
		types.singleton("ClassName"),
		types.singleton("UniqueId"),
		types.singleton("Parent"),
		types.singleton("Name"),
	})

	while current do
		for property, value in current:properties() do
			if table.find(read_only_properties, property) then
				continue
			end

			local value_read = value.read
			if not value_read or value_read.tag == "function" or value_read.tag == "intersection" then
				continue
			end
			-- Studio exposes signals as externs; luau-lsp uses tables with Connect.
			if value_read == RobloxSignal then
				continue
			end
			if value_read:is("table") then
				local connect = value_read:readproperty(types.singleton("Connect"))
				if connect and connect:is("function") then
					continue
				end
			end
			local value_write = value.write
			if value_write then
				properties:setproperty(property, value_write)
			end
		end

		current = current:readparent()
	end

	return properties
end

-- Later fields override earlier fields, matching token updates.
export type function Merge(base: type, overrides: type): type
	local result = types.newtable()
	for _, source in { base, overrides } do
		if not source:is("table") then
			continue
		end
		for key, property in source:properties() do
			result:setproperty(key, property.read)
		end
		local indexer = source:indexer()
		if indexer then
			result:setindexer(indexer.index, indexer.readresult)
		end
	end
	return result
end

type function TokenRefsFor(tokens: type, property_type: type): type?
	if not tokens:is("table") then
		return nil
	end

	local indexer = tokens:indexer()
	if indexer and indexer.readresult:issubtypeof(property_type) then
		return types.string
	end

	local refs: type? = nil

	for key, property in tokens:properties() do
		if not (key:is("singleton") and type(key:value()) == "string") then
			continue
		end

		local name = key:value() :: string
		-- Token table keys are bare names; rule/query values reference them as "$Name".
		local token_type = property.read
		if not token_type then
			continue
		end
		if token_type:issubtypeof(property_type) then
			local reference = types.singleton("$" .. name)
			refs = if refs then types.unionof(refs, reference) else reference
		end
	end

	return refs
end

type function WithTokenValues(properties: type, tokens: type): type
	local result = types.newtable()

	for key, property in properties:properties() do
		local value_type = property.read
		if not value_type then
			continue
		end
		local token_refs = TokenRefsFor(tokens, value_type)
		result:setproperty(
			key,
			types.optional(if token_refs then types.unionof(value_type, token_refs) else value_type)
		)
	end

	return result
end

type function SubjectClassName(selector: type): type
	if not (selector:is("singleton") and type(selector:value()) == "string") then
		return types.singleton("")
	end

	local selector_text = selector:value() :: string
	local subject = selector_text

	for piece in string.gmatch(selector_text, "[^>+~]+") do
		local trimmed = string.gsub(piece, "^%s+", "")
		trimmed = string.gsub(trimmed, "%s+$", "")
		if trimmed ~= "" then
			subject = trimmed
		end
	end

	local component: string? = nil
	for name in string.gmatch(subject, "::([%w_]+)") do
		component = name
	end
	if component then
		return types.singleton(component)
	end

	subject = string.gsub(subject, "::[%w_]+", "")
	subject = string.gsub(subject, ":[%w_]+", "")
	subject = string.gsub(subject, "@[%w_%-]+", "")
	subject = string.gsub(subject, "%.[%w_%-]+", "")
	subject = string.gsub(subject, "#[%w_%-]+", "")
	subject = string.gsub(subject, "^%s+", "")
	subject = string.gsub(subject, "%s+$", "")

	return types.singleton(subject)
end

export type function TagsFrom(selector: type): type
	local result = types.newtable()
	if not (selector:is("singleton") and type(selector:value()) == "string") then
		return result
	end

	local text = selector:value() :: string
	for name in string.gmatch(text, "%.([%w_%-]+)") do
		result:setproperty(types.singleton(name), types.singleton(true))
	end
	return result
end

type function PropertiesForSelector(selector: type): type
	if not (selector:is("singleton") and type(selector:value()) == "string") then
		return WritableProperties(RobloxGuiObject)
	end

	local text = selector:value() :: string
	local properties = types.newtable()
	local found = false

	for part in string.gmatch(text .. ",", "([^,]+),") do
		local trimmed = string.gsub(part, "^%s+", "")
		trimmed = string.gsub(trimmed, "%s+$", "")
		if trimmed == "" then
			continue
		end

		local class_name = SubjectClassName(types.singleton(trimmed))
		local writable = WritableProperties(Instances:readproperty(class_name) or RobloxGuiObject)
		-- Flatten selector lists into one property table. An intersection of tables
		-- cannot be inspected with :properties() by WithTokenValues.
		for key, property in writable:properties() do
			local value = property.read
			if value then
				local previous = properties:readproperty(key)
				properties:setproperty(
					key,
					if previous and previous ~= value then types.intersectionof(previous, value) else value
				)
			end
		end
		found = true
	end

	return if found then properties else WritableProperties(RobloxGuiObject)
end

export type function StyleProperties(selector: type, tokens: type): type
	local instance_properties = PropertiesForSelector(selector)
	local properties = WithTokenValues(instance_properties, tokens)
	local query = WithTokenValues(Merge(WritableProperties(RobloxStyleQuery), instance_properties), tokens)
	local queries = types.newtable()
	queries:setindexer(types.string, query)

	local transition = types.newtable()
	transition:setproperty(types.singleton("Default"), types.optional(RobloxTweenInfo))
	for key in properties:properties() do
		transition:setproperty(key, types.optional(RobloxTweenInfo))
	end

	properties:setproperty(types.singleton("Priority"), types.optional(types.number))
	properties:setproperty(types.singleton("Transition"), types.optional(transition))
	properties:setproperty(types.singleton("queries"), types.optional(queries))
	return properties
end

-- Private type-only metadata carries the state accumulated by fluent calls.
type SheetData<Tokens, Tags> = {
	instance: RobloxStyleSheet,
	_tokens: Tokens,
	_tags: Tags,
}

type TokensOf<Self> = index<Self, "_tokens">
type TagsOf<Self> = index<Self, "_tags">
type TagValue<Self> = keyof<TagsOf<Self>> | () -> keyof<TagsOf<Self>>?

type TokenState<Self, NewTokens> = SheetData<Merge<TokensOf<Self>, NewTokens>, TagsOf<Self>>
type DerivedState<Self, Other> = SheetData<Merge<TokensOf<Other>, TokensOf<Self>>, Merge<TagsOf<Self>, TagsOf<Other>>>
type RuleState<Self, Selector> = SheetData<TokensOf<Self>, Merge<TagsOf<Self>, TagsFrom<Selector>>>

-- Infer each method's state from Self, delaying property generation until the
-- receiver is known. Keep setmetatable returns inline: a recursive Sheet alias
-- here loses inference in Solver V2.
type SheetPrototype = {
	__index: SheetPrototype,
	tags: <Self>(self: Self, tags: { TagValue<Self> }) -> Action,
	link: (self: { instance: RobloxStyleSheet }) -> Action,
	tokens: <Self, NewTokens>(
		self: Self,
		tokens: NewTokens
	) -> setmetatable<TokenState<Self, NewTokens>, SheetPrototype>,
	derive: <Self, Other>(self: Self, from: Other) -> setmetatable<DerivedState<Self, Other>, SheetPrototype>,
	rule: <Self, Selector>(
		self: Self,
		selector: Selector | ""
	) -> (StyleProperties<Selector, TokensOf<Self>>) -> setmetatable<RuleState<Self, Selector>, SheetPrototype>,
}

export type Sheet<Tokens = {}, Tags = {}> = setmetatable<SheetData<Tokens, Tags>, SheetPrototype>

local function create_rule(style_sheet: RobloxStyleSheet, selector: string, payload: { [string]: unknown })
	local rule = Instance.new("StyleRule")
	rule.Selector = selector
	rule.Name = selector

	local properties = {} :: { [string]: unknown }
	local queries = payload.queries :: { [string]: { [string]: unknown } }
	local transitions = payload.Transition :: { [string]: TweenInfo }
	local priority = payload.Priority :: number?

	for key, value in payload do
		if key == "Priority" or key == "Transition" or key == "queries" then
			continue
		end
		properties[key] = value
	end

	if priority then
		rule.Priority = priority
	end
	rule:SetProperties(properties)

	if transitions then
		local default_transition: TweenInfo? = nil

		for prop_name, tween_info_value in transitions do
			if string.lower(prop_name) == "default" then
				default_transition = tween_info_value
				transitions[prop_name] = nil
			end
		end

		if default_transition then
			rule:SetDefaultPropertyTransition(default_transition)
		end
		rule:SetPropertyTransitions(transitions)
	end

	if queries then
		for name, definition in queries :: { [string]: { [string]: unknown } } do
			local query = Instance.new("StyleQuery")
			query:SetConditions(definition)
			query.Name = name
			query.Parent = rule
		end
	end

	rule.Parent = style_sheet
end

type RuntimeSheet = { instance: RobloxStyleSheet }

local style_sheet_prototype = {}
style_sheet_prototype.__index = style_sheet_prototype

function style_sheet_prototype.rule(self: RuntimeSheet, selector: string)
	return function(payload: { [string]: unknown })
		create_rule(self.instance, selector, payload)
		return self
	end
end

function style_sheet_prototype.tokens(self: RuntimeSheet, tokens: { [string]: unknown })
	local instance = self.instance

	for token_name, value in tokens do
		instance:SetAttribute(token_name, value)
	end
	return self
end

function style_sheet_prototype.derive(self: RuntimeSheet, other: RuntimeSheet)
	local instance = self.instance
	local derives = self.instance:GetDerives()
	table.insert(derives, other.instance)
	self.instance:SetDerives(next_derives)
	return self
end

function style_sheet_prototype.tags(_self: RuntimeSheet, selected_tags: { string | () -> string? })
	return tags(selected_tags)
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

local function style_sheet(): Sheet<{}, {}>
	return table.freeze(setmetatable({
		instance = Instance.new("StyleSheet"),
	}, style_sheet_prototype)) :: any
end

return style_sheet
