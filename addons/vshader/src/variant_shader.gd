@tool
extends Resource
class_name VariantShader

enum AutoRecompilationMode { RECOMPILE, RECOMPILE_IGNORE_PERMUTATION_EXPLOSION, SUSPENDED }

@export_tool_button("Recompile", "Reload")
var __recompile = _on_user_recompile_request

@export_storage
var _source: Shader = null

@export
var source: Shader:
	set(value):
		await set_source_async(value)
	get:
		return _source

@export
var editor_only_generation: bool = true

@export
var auto_recompilation_mode: AutoRecompilationMode = AutoRecompilationMode.RECOMPILE

func _on_exclusions_extensions_updated_async():
	await _rebuild_cache_async(source, true)

@export
var exclusions: Dictionary[String, VariantShaderExclusions] = {}:
	set(value):
		if exclusions != null:
			for excl_key in exclusions.keys():
				var excl := exclusions[excl_key]
				if excl == null: continue
				excl.changed.disconnect(_on_exclusions_extensions_updated_async)
				
		exclusions = value
		
		if value != null:
			for excl_key in value:
				var excl := value[excl_key]
				if excl == null: continue
				excl.changed.connect(_on_exclusions_extensions_updated_async)
				
		await _rebuild_cache_async(source, true)

@export
var extensions: Dictionary[String, VariantShaderExtension] = {}:
	set(value):
		if extensions != null:
			for ext_key in extensions.keys():
				var ext := extensions[ext_key]
				if ext == null: continue
				ext.changed.disconnect(_on_exclusions_extensions_updated_async)
				
		extensions = value
		
		if value != null:
			for ext_key in value.keys():
				var ext := value[ext_key]
				if ext == null: continue
				ext.changed.connect(_on_exclusions_extensions_updated_async)
		
		await _rebuild_cache_async(source, true)

@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE)
var cache: VariantShaderGeneratedCache = null

func _rebuild_cache_async(shader: Shader, automatic: bool):
	if shader == null:
		cache = null
		return
	
	if auto_recompilation_mode == AutoRecompilationMode.SUSPENDED:
		return
	
	if editor_only_generation and not Engine.is_editor_hint():
		push_error("VSHADER: Shader generation is disabled at runtime (editor_only_generation == true)")
		return
		
	var res := await VariantShaderGeneratedCache.generate_from_async(
		shader, auto_recompilation_mode != AutoRecompilationMode.RECOMPILE_IGNORE_PERMUTATION_EXPLOSION,
		extensions, exclusions, automatic
	)
	match res.status:
		VariantShaderGeneratedCache.ValidateStatus.OK:
			pass
		VariantShaderGeneratedCache.ValidateStatus.PERMUTATION_EXPLOSION_ACCEPTED:
			auto_recompilation_mode = AutoRecompilationMode.RECOMPILE_IGNORE_PERMUTATION_EXPLOSION
		VariantShaderGeneratedCache.ValidateStatus.PERMUTATION_EXPLOSION_REJECTED:
			auto_recompilation_mode = AutoRecompilationMode.SUSPENDED
			cache = null
			return
	
	cache = res.cache
	emit_changed()

func try_get_shader(options: Dictionary[String, String], ignore_unknown_variants: bool = false) -> Shader:
	if cache == null: return null
	return cache.try_get_shader(options, ignore_unknown_variants)

func get_or_compile_shader(options: Dictionary[String, String], ignore_unknown_variants: bool = false) -> Shader:
	if cache == null: return null
	return cache.get_or_compile_shader(options, ignore_unknown_variants, editor_only_generation)

func is_excluded(variant: VariantShaderVariant, option: String) -> bool:
	if not exclusions: return false
	if not exclusions.has(variant.name): return false
	var excl := exclusions[variant.name]
	return excl.options.has(option)

func try_get_variant(name: String) -> VariantShaderVariant:
	if cache == null:
		push_error("VSHADER: No source shader configured")
		return null
		
	for v in cache.variants:
		if v.name == name: return v
	return null

func set_source_async(shader: Shader):
	var old_source := _source
	_source = shader
	if old_source == shader:
		return
	
	await _rebuild_cache_async(shader, true)

func _on_user_recompile_request():
	await _rebuild_cache_async(source, false)
	emit_changed()
