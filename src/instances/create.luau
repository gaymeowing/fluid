local bind = require("./bind")

type Instances = {
	AudioChannelSplitter: AudioChannelSplitter,
	AudioPitchShifter: AudioPitchShifter,
	AudioDeviceOutput: AudioDeviceOutput,
	AudioChannelMixer: AudioChannelMixer,
	AudioTextToSpeech: AudioTextToSpeech,
	AudioDeviceInput: AudioDeviceInput,
	AudioDistortion: AudioDistortion,
	AudioCompressor: AudioCompressor,
	AudioEqualizer: AudioEqualizer,
	AudioAnalyzer: AudioAnalyzer,
	AudioListener: AudioListener,
	AudioRecorder: AudioRecorder,
	AudioLimiter: AudioLimiter,
	AudioFlanger: AudioFlanger,
	AudioEmitter: AudioEmitter,
	AudioPlayer: AudioPlayer,
	AudioReverb: AudioReverb,
	AudioFilter: AudioFilter,
	ArcHandles: ArcHandles,
	AudioFader: AudioFader,
	AudioEcho: AudioEcho,
	AdGui: AdGui,
	BoxHandleAdornment: BoxHandleAdornment,
	BillboardGui: BillboardGui,
	BlurEffect: BlurEffect,
	CylinderHandleAdornment: CylinderHandleAdornment,
	ConeHandleAdornment: ConeHandleAdornment,
	CanvasGroup: CanvasGroup,
	Camera: Camera,
	DialogChoice: DialogChoice,
	DragDetector: DragDetector,
	Dialog: Dialog,
	Folder: Folder,
	Frame: Frame,
	Highlight: Highlight,
	Handles: Handles,
	ImageHandLeAdornment: ImageHandleAdornment,
	ImageButton: ImageButton,
	ImageLabel: ImageLabel,
	LineHandleAdornment: LineHandleAdornment,
	ProximityPrompt: ProximityPrompt,
	Part: Part,
	SphereHandLeAdornment: SphereHandleAdornment,
	SelectionSphere: SelectionSphere,
	ScrollingFrame: ScrollingFrame,
	SelectionBox: SelectionBox,
	StyleDerive: StyleDerive,
	SurfaceGui: SurfaceGui,
	StyleSheet: StyleSheet,
	SoundGroup: SoundGroup,
	StyleLink: StyleLink,
	ScreenGui: ScreenGui,
	StyleBase: StyleBase,
	StyleRule: StyleRule,
	Sound: Sound,
	TextButton: TextButton,
	TextLabel: TextLabel,
	TextBox: TextBox,
	UIAspectRatioConstraint: UIAspectRatioConstraint,
	UITextSizeConstraint: UITextSizeConstraint,
	UISizeConstraint: UISizeConstraint,
	UIDragDetector: UIDragDetector,
	UITableLayout: UITableLayout,
	UIPageLayout: UIPageLayout,
	UIGridLayout: UIGridLayout,
	UIListLayout: UIListLayout,
	UIGradient: UIGradient,
	UIFlexItem: UIFlexItem,
	UIPadding: UIPadding,
	UIStroke: UIStroke,
	UICorner: UICorner,
	UIScale: UIScale,
	ViewportFrame: ViewportFrame,
	VideoFrame: VideoFrame,
	WireframeHandleAdornment: WireframeHandleAdornment,
	WorldModel: WorldModel,
	Wire: Wire,
}

type UnknownConnectCallback = (...any) -> ()

type Signal = RBXScriptSignal

type function get_connect(v: type): type?
	local connect_names = { 
		types.singleton("Connect"), 
		types.singleton("connect")
	}

	for _, name in connect_names do
		local connect = v:readproperty(name)

		if connect and connect:is("function") then
			local head = connect:parameters().head

			if not head then
				continue
			end
			local callback = head[2]

			if callback and callback:is("function") then
				return callback
			end
		end
	end

	return nil
end

type function is_signal(v: type): type?
	if v == Signal and v:is("class") then
		return UnknownConnectCallback
	elseif v:is("table") then
		local connect = get_connect(v)

		if connect then
			return connect
		end

		local metatable = v:metatable()

		if metatable then
			connect = get_connect(metatable)

			if connect then
				return connect
			end
		end
	end

	return nil
end

type Action<T> = {
	read callback: () -> T,
	read priority: number,
}

type function GetProperties(instance, instancetype)
	local properties = types.newtable()

	local function insert(object)
		if object:readparent() == nil then
			return
		end
		for key, value in object:properties() do
			local is_a_signal = is_signal(value.read)
			if is_a_signal and value.read:is("table") then -- luau-lsp
				local connect_fn = is_a_signal
				local params = connect_fn:parameters()
				if params.head then
					table.remove(params.head, 1)
				end
			elseif
				value.read:is("function") or value.read:is("intersection")
			then
				continue
			elseif value.write then
				local type = types.optional(
					types.unionof(
						types.newfunction({}, { head = { value.read } }),
						value.write :: any
					)
				)

				properties:setproperty(key :: any, type)
			end
		end

		insert(object:readparent())
	end
	insert(instance)

	local action = Action(instancetype)

	local function_returns_child = types.newfunction()
	local nested_table_or_function_or_child = types.newtable()
	local union = types.unionof(
		instancetype,
		function_returns_child,
		nested_table_or_function_or_child
	)

	nested_table_or_function_or_child:setindexer(types.number, union)
	function_returns_child:setreturns({ union })

	properties:setindexer(
		types.number,
		types.optional(
			types.unionof(
				action,
				instancetype,
				function_returns_child,
				properties
			)
		)
	)

	return properties
end

type function GetInstance(instance_name, instancetype)
	if not instance_name:is("singleton") then
		return instancetype
	end

	return Instances:readproperty(instance_name:value()) or instancetype
end

local function try_create_inst(class_name: string): Instance
	local success, result = pcall(Instance.new, class_name)
	if not success then
		-- error at the location of the create call
		error(`Instance class "{class_name}" does not exist`, 3)
	end

	return result
end

local function create<Class>(
	class_name: Class
): (
	GetProperties<GetInstance<Class, Instances, Instance>, Instance>
) -> GetInstance<Class, Instances, Instance>
	return function(props: GetProperties<
		GetInstance<Class, Instances, Instance>,
		Instance
	>): GetInstance<Class, Instances, Instance>
		return bind(try_create_inst(class_name), props :: any) :: any
	end
end

return create
