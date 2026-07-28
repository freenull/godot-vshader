@tool
extends Resource
class_name VariantShader

class Promise:
	signal emitted(which: Signal)
	
	func _init(signals: Array[Signal]):
		for sig in signals:
			sig.connect(func(): _emit(sig))
	
	func _emit(which: Signal):
		emitted.emit(which)

const DANGEROUS_PERMUTATION_COUNT_THRESHOLD := 1024

var _variants: Array[VariantShaderVariant]

func _on_base_shader_requires_update():
	recompile_all()

## When enabled, if the shader permutation count for the next generation is detected to exceed 1024,
## a confirmation dialog will be displayed to continue generation or temporarily suspend it.[br]
## If generation is continued, this flag is automatically disabled.
@export
var warn_on_dangerous_permutation_count: bool = true

## While enabled, changes to the base shader or other parameters will not trigger regeneration of
## shader permutations.
@export
var suspend_recompilation: bool = false:
	set(value):
		suspend_recompilation = value
		if not suspend_recompilation:
			recompile_all()

## Excludes generating permutations which contain certain options of variants.
## [br][br]Entries are of the form [code]VARIANT=OPTION[/code] (exclude specific option of
## specific variant) or [code]VARIANT=*[/code] (exclude all options of the variant except
## the default option). Multiple entries for the same [code]VARIANT[/code] may be specified.
@export
var excluded_options: Array[String] = []:
	set(value):
		excluded_options = value
		_on_base_shader_requires_update()

## Reference shader object containing source code with variant declarations.
@export
var base_shader: Shader:
	set(value):
		if base_shader != null:
			base_shader.changed.disconnect(_on_base_shader_requires_update)
		base_shader = value
		if base_shader != null:
			base_shader.changed.connect(_on_base_shader_requires_update)
		
		_on_base_shader_requires_update()

## Dictionary of all generated shader permutations.
@export_custom(PROPERTY_HINT_TYPE_STRING, "", PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_EDITOR)
var shader_cache: Dictionary[String, Shader]

static func _parse_variant_def(variant_def: String) -> VariantShaderVariant:
	var elems := variant_def.split(" ", false)
	if elems.size() == 0:
		push_warning("VariantShader: invalid definition of variant: missing name")
		return null
		
	var name := elems[0]
	elems.remove_at(0)
	
	if elems.size() == 0:
		push_warning("VariantShader: invalid definition of variant ", name, ": missing options")
		return null
	
	var variant := VariantShaderVariant.new()
	variant.name = name
	variant.values = elems
	return variant

static func _parse_variants(code: String) -> Array[VariantShaderVariant]:
	var variants: Array[VariantShaderVariant] = []
	
	var lineno = 0
	for line in code.split("\n"):
		lineno += 1
		line = line.strip_edges()
		if not line.begins_with("//"):
			continue
		line = line.substr(2)
		line = line.strip_edges(true, false)
		if not line.begins_with("@variant"): continue
		line = line.substr("@variant".length())
		line = line.strip_edges(true, false)
		var variant := _parse_variant_def(line)
		if variant != null: variants.append(variant)
		else:
			push_warning("VariantShader: failed parsing variant definition at line ", lineno)
	
	return variants
		

func _compile_permutations(args: Array[String]):
	if args.size() >= _variants.size():
		_compile_cached(args)
		return
	
	var next_variant_idx = args.size()
	var variant := _variants[next_variant_idx]
	for option in variant.values:
		if is_excluded(variant, option):
			continue
		var args_perm := args.duplicate()
		args_perm.append(option)
		_compile_permutations(args_perm)

func _cache_key(args: Array[String]) -> String:
	var id_string := ""
	var first := true
	var idx := 0
	for value_key in args:
		if idx >= _variants.size():
			push_warning("VariantShader: number of args passed to _compile is larger than number of variants")
			break
		var variant := _variants[idx]
		
		if is_excluded(variant, value_key):
			push_warning("VariantShader: value '", value_key, "' of variant '", variant.name, "' is excluded and cannot be used")
			return ""
			
		if variant.get_value(value_key) < 0:
			return ""
		
		if not first:
			id_string += ","
		id_string += variant.name
		id_string += "="
		id_string += value_key
		first = false
		idx += 1
	
	return id_string

func _strip_variant_instructions(code: String) -> String:
	var lines := code.split("\n")
	for i in range(lines.size() - 1, 0, -1):
		var line := lines[i].strip_edges()
		if not line.begins_with("//"): continue
		line = line.substr(2).strip_edges(true, false)
		if not line.begins_with("@variant"): continue
		lines.remove_at(i)
	return "\n".join(lines)

func _compile_uncached(args: Array[String]) -> Shader:
	if base_shader == null:
		push_warning("VariantShader: cannot compile variant because base_shader is unset")
		return null
	var prefix := ""
	var idx := 0
	
	var encountered_symbols: Dictionary[String, bool] = {}
	
	for value_key in args:
		if idx >= _variants.size():
			push_warning("VariantShader: number of args passed to _compile is larger than number of variants")
			break
		var variant := _variants[idx]
		if is_excluded(variant, value_key):
			push_warning("VariantShader: value '", value_key, "' of variant '", variant.name, "' is excluded and cannot be used")
			continue
		var value_int := variant.get_value(value_key)
		if value_int < 0:
			push_warning("VariantShader: value '", value_key, "' is not a valid option for variant '", variant.name, "'")
			continue
		
		var macro_name := variant.name + "_" + value_key
		if encountered_symbols.has(macro_name):
			push_warning("VariantShader: invalid name of variant '", variant.name, "' option '", value_key, "': the resulting symbol '", macro_name, "' is already generated by a previous variant or option")
			continue
		
		encountered_symbols[macro_name] = true
		prefix += "#define " + macro_name + "\n"
				
		idx += 1
	
	var shader := Shader.new()
	shader.code = prefix + base_shader.code
	return shader

func _compile_cached(args: Array[String]) -> Shader:
	var key := _cache_key(args)
	if key == "":
		return null
	if shader_cache.has(key):
		return shader_cache[key]
		
	var shader := _compile_uncached(args)
	if shader == null: return null
	shader_cache[key] = shader
	return shader

func _get_permutation_count() -> int:
	var count := 1
	for variant in _variants:
		var usable_options := variant.values.size()
		for value in variant.values:
			if is_excluded(variant, value): usable_options -= 1
		count *= usable_options
	
	return count

func compile(params: Dictionary[String, String], ignore_missing: bool = false) -> Shader:
	var args: Array[String] = []
	for variant in _variants:
		# first option = oifault
		args.append(variant.get_key(0))
		
	for variant_key in params.keys():
		var variant_idx := 0
		for variant in _variants:
			if variant.name == variant_key:
				break 
			variant_idx += 1
		
		if variant_idx >= _variants.size():
			if not ignore_missing:
				push_warning("VariantShader: invalid variant key '", variant_key, "' passed to compile()")
			continue
		
		args[variant_idx] = params[variant_key]
	
	return _compile_cached(args)

func try_compile(params: Dictionary[String, String], ignore_missing: bool = false) -> Shader:
	if base_shader == null: return
	return compile(params, ignore_missing)

func recompile_all():
	if suspend_recompilation:
		return
		
	shader_cache = {}
	if base_shader == null:
		_variants = []
		return
	
	_variants = _parse_variants(base_shader.code)
	
	if warn_on_dangerous_permutation_count:
		var permutation_count := _get_permutation_count()
		print(permutation_count)
		if permutation_count >= DANGEROUS_PERMUTATION_COUNT_THRESHOLD:
			var vshader_desc := ""
			if resource_path != "":
				vshader_desc = str(" (", resource_path, ")")
			
			var dialog := ConfirmationDialog.new()
			dialog.title = "Dangerous number of VariantShader permutations"
			dialog.dialog_text = str(
				"Compiling this VariantShader", vshader_desc, " will lead to ", permutation_count, " shader permutations being generated.\n",
				"Each permutation is a separate Shader instance with a separate copy of the source code. This may have a significant effect on RAM usage, disk usage and loading speed.\n",
				"Are you sure you want to continue?\n",
				"Aborting will suspend recompilation. You can enable it back through the suspend_recompilation property.\n",
				"Accepting will continue generation and disable this confirmation dialog for this shader."
			)
			EditorInterface.get_base_control().add_child(dialog)
			
			dialog.popup_centered()
			var which = await Promise.new([dialog.confirmed, dialog.canceled]).emitted
			var do_continue = which == dialog.confirmed
			dialog.queue_free()
			
			print(do_continue)
			
			if do_continue:
				warn_on_dangerous_permutation_count = false
			else:
				suspend_recompilation = true
				push_warning("VariantShader: recompilation suspended as user rejected generating ", permutation_count, " shaders")
				return
	
	_compile_permutations([])
	changed.emit()

func has_variant(name: String) -> bool:
	for variant in _variants:
		if variant.name == name:
			return true
	return false

func try_get_variant(name: String) -> VariantShaderVariant:
	for variant in _variants:
		if variant.name == name:
			return variant
	return null

func variants() -> Array[VariantShaderVariant]:
	return _variants

func is_excluded(variant: VariantShaderVariant, value: String):
	if excluded_options.has(variant.name + "=" + value): return true
	# X=* must leave behind the default value otherwise no permutation can be constructed
	if variant.get_value(value) != 0:
		return excluded_options.has(variant.name + "=*")

static func create_from_shader(shader: Shader) -> VariantShader:
	var vshader := new()
	vshader.base_shader = shader
	return vshader
	
