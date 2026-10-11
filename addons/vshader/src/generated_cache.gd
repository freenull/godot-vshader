extends Resource
class_name VariantShaderGeneratedCache

class Promise:
	signal emitted(which: Signal)

	func _init(signals: Array[Signal]):
		for sig in signals:
			sig.connect(func(): _emit(sig))

	func _emit(which: Signal):
		emitted.emit(which)

enum ValidateStatus { OK, ERROR, PERMUTATION_EXPLOSION_REJECTED, PERMUTATION_EXPLOSION_ACCEPTED }

class GenerateResult:
	var status: ValidateStatus
	var cache: VariantShaderGeneratedCache
	
	func _init(status: ValidateStatus, cache: VariantShaderGeneratedCache):
		self.status = status
		self.cache = cache

@export_storage
var tokens: Array[VariantShaderToken] = []

@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE)
var variants: Array[VariantShaderVariant] = []

@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE)
var permutation_count: int = 1

@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE)
var _permutation_cache: Dictionary[String, Shader] = {}

func _parse_vshader_directive_variant_enumlike(kind: VariantShaderVariantEnumLike.Kind, name: String, tokenizer: VariantShaderTokenizer) -> bool:
	var tok := tokenizer.next_token()
	if tok.type != VariantShaderToken.TokenType.BRACE_OPEN:
		push_error("VSHADER: Expected enum block at ", tok.region, ", got: ", tok.type_name())
		return false
	
	var v_enum := VariantShaderVariantEnumLike.new()
	v_enum.kind = kind
	v_enum.name = name
	
	var default_assigned := false
	
	var next_value := 0
	while true:
		tok = tokenizer.next_token()
		if tok.type == VariantShaderToken.TokenType.BRACE_CLOSE:
			break
		elif tok.type == VariantShaderToken.TokenType.COMMA:
			continue
		
		var option_name: String
		var option_value: int
		var is_int_option: bool = false
		if tok.type == VariantShaderToken.TokenType.IDENTIFIER:
			option_name = tok.value
			option_value = next_value
		else:
			if kind == VariantShaderVariantEnumLike.Kind.VALUE and tok.type == VariantShaderToken.TokenType.OTHER and tok.value.is_valid_int():
				is_int_option = true
				option_name = tok.value
				option_value = int(tok.value)
			else:
				push_error("VSHADER: Expected enum entry at ", tok.region, ", got: ", tok.type_name())
				return false
		
		if v_enum.values.has(option_name):
			push_error("VSHADER: Duplicate enum entry '", option_name, "' at ", tok.region)
			return false
		
		if not is_int_option:
			var peek := tokenizer.peek_token()
			if peek.type == VariantShaderToken.TokenType.ASSIGN:
				tokenizer.next_token()
				tok = tokenizer.next_token()
				
				if tok.type != VariantShaderToken.TokenType.OTHER or not tok.value.is_valid_int():
					push_error("VSHADER: Expected valid enum value (int) at ", tok.region, ", got: ", tok.type_name())
					return false
				
				option_value = int(tok.value)
		
		next_value = option_value + 1
	
		v_enum.values[option_name] = option_value
		if not default_assigned:
			v_enum.default_option_name = option_name
			default_assigned = true
	
	if not default_assigned:
		push_error("VSHADER: Enum and int variants requier at least one entry, but variant '", name, "' at ", tok.region, " has none")
		return false
	
	variants.append(v_enum)
		
	return true

func _is_valid_inc_path(path: String) -> bool:
	if not path.ends_with(".gdshaderinc"):
		return false
	return true

func _parse_vshader_directive_variant_inc(cwd_path: String, name: String, tokenizer: VariantShaderTokenizer) -> bool:
	var tok := tokenizer.next_token()
	if tok.type != VariantShaderToken.TokenType.STRING:
		push_error("VSHADER: Expected path to stub include file at ", tok.region, ", got: ", tok.type_name())
		return false
	
	if not _is_valid_inc_path(tok.value):
		push_error("VSHADER: Invalid path to *.gdshaderinc stub file at ", tok.region, ": ", tok.value)
		return false
	
	var v_inc = VariantShaderVariantInc.new()
	v_inc.name = name
	v_inc.base_dir = cwd_path
	v_inc.stub_path = tok.value
	if not v_inc.stub_path.is_absolute_path():
		v_inc.stub_path = cwd_path.path_join(v_inc.stub_path)
	
	tok = tokenizer.peek_token()
	if tok.type == VariantShaderToken.TokenType.BRACE_OPEN:
		tokenizer.next_token()
		
		var first := true
		while true:
			tok = tokenizer.next_token()
			if tok.type == VariantShaderToken.TokenType.BRACE_CLOSE:
				break
			
			if not first and tok.type != VariantShaderToken.TokenType.COMMA:
				push_error("VSHADER: Expected comma before next entry of default include list at ", tok.region, ", got: ", tok.type_name())
				return false
			if not first:
				tok = tokenizer.next_token()
			first = false
			
			if tok.type != VariantShaderToken.TokenType.STRING:
				push_error("VSHADER: Expected string with default include list entry at ", tok.region, ", got: ", tok.type_name())
				return false
		
			var path := tok.value
			if not path.is_absolute_path():
				path = cwd_path.path_join(tok.value)
			path = path.simplify_path()
			if not _is_valid_inc_path(path):
				push_error("VSHADER: Invalid path to *.gdshaderinc file at ", tok.region, ": ", path)
				return false
			
			v_inc.inc_paths.append(path)
	
	variants.append(v_inc)
		
	return true

func _parse_vshader_directive_variant(cwd_path: String, tokenizer: VariantShaderTokenizer) -> bool:
	var name := tokenizer.next_token()
	if name.type != VariantShaderToken.TokenType.IDENTIFIER:
		push_error("VSHADER: Expected variant name at ", name.region, ", got: ", name.type_name())
		return false
	if not name.value.is_valid_ascii_identifier():
		push_error("VSHADER: Variant name at ", name.region, " is not a valid ASCII identifier: ", name.value)
		return false
		
	var type := tokenizer.next_token()
	if type.type != VariantShaderToken.TokenType.IDENTIFIER:
		push_error("VSHADER: Expected variant type name at ", type.region, ", got: ", type.type_name())
		return false
	
	match type.value:
		"enum":
			return _parse_vshader_directive_variant_enumlike(VariantShaderVariantEnumLike.Kind.ENUM, name.value, tokenizer)
		"int":
			return _parse_vshader_directive_variant_enumlike(VariantShaderVariantEnumLike.Kind.VALUE, name.value, tokenizer)
		"inc":
			return _parse_vshader_directive_variant_inc(cwd_path, name.value, tokenizer)
	
	push_error("VSHADER: Unknown variant type '", type.value, "' at ", type.region)
	return false

func _parse_vshader_directive(cwd_path: String, key: VariantShaderToken, tokenizer: VariantShaderTokenizer) -> bool:
	match key.value:
		"variant":
			if not _parse_vshader_directive_variant(cwd_path, tokenizer): return false
		_:
			push_error("VSHADER: Unknown VariantShader directive '", key.value, "' at ", key.region)
			return true
	
	var tok := tokenizer.next_token()
	if tok.type != VariantShaderToken.TokenType.VSHADER_DIRECTIVE_END:
		push_error("VSHADER: Expected end of VariantShader directive token at ", tok.region, ", got: ", tok.type_name())
	return true

func _tokenize(source: Shader, extensions: Dictionary[String, VariantShaderExtension] = {}):
	var tokenizer = VariantShaderTokenizer.new(source.code)
	var tok := tokenizer.next_token()
	
	var cwd_path := source.resource_path
	if cwd_path != "":
		cwd_path = cwd_path.get_base_dir()
		
	while tok.type != VariantShaderToken.TokenType.EOF:
		if tok.type == VariantShaderToken.TokenType.VSHADER_DIRECTIVE_BEGIN:
			_parse_vshader_directive(cwd_path, tok, tokenizer)
			tok = tokenizer.next_token()
			continue
		
		tokens.append(tok)
		tok = tokenizer.next_token()
	
	_fix_include_paths(source.resource_path.get_base_dir())
	
	if extensions != null:
		for variant in variants:
			var extension := extensions.get(variant.name, null)
			if extension == null: continue
			variant.extend(extension)
	
	permutation_count = 1
	for v in variants:
		permutation_count *= v.options().size()

func _fix_include_paths(base_dir: String):
	var token_count := tokens.size()
	for i in range(token_count):
		var token := tokens[i]
		if token.type != VariantShaderToken.TokenType.PREPROCESSOR_DIRECTIVE_BEGIN: continue
		if token.value != "include": continue
		
		i += 1
		if i >= token_count: return
		token = tokens[i]
		
		if token.type != VariantShaderToken.TokenType.STRING: continue
		var path_token := token
		
		i += 1
		if i >= token_count: return
		token = tokens[i]
		
		if token.type != VariantShaderToken.TokenType.PREPROCESSOR_DIRECTIVE_END: continue
		var path := path_token.value
		if not path.is_absolute_path():
			path = base_dir.path_join(path)
			
		path_token.value = path

func _generate_and_cache_shader(option_chain: PackedStringArray) -> Shader:
	var cache_key := ""
	var first := true
	
	# Variants' apply() functions are assumed not to mutate tokens themselves, just the array
	var new_tokens := tokens.duplicate(false)
	for i in range(option_chain.size()):
		var variant := variants[i]
		var option := option_chain[i]
		variant.apply(new_tokens, option)
		
		if not first:
			cache_key += ";"
		first = false
		cache_key += str(variant.name, "=", option)
	
	var comp_settings := VariantShaderTokenizer.TokenCompilerSettings.new()
	comp_settings.skip_comments = true
	comp_settings.skip_vshader_directives = true
	var comp := VariantShaderTokenizer.TokenCompiler.new(comp_settings)
	comp.compile_all(new_tokens)
	
	var shader := Shader.new()
	shader.code = comp.code
	
	_permutation_cache[cache_key] = shader
	
	return shader

func _option_chain_to_cache_key(option_chain: PackedStringArray) -> String:
	var key := ""
	var first := true
	
	for i in range(option_chain.size()):
		var variant := variants[i]
		var option := option_chain[i]
		
		if not first:
			key += ";"
		first = false
		key += str(variant.name, "=", option)
		
	return key

func _compile_permutations(exclusions: Dictionary[String, VariantShaderExclusions], option_chain: PackedStringArray):
	var option_chain_size := option_chain.size()
	
	if option_chain_size == variants.size():
		_generate_and_cache_shader(option_chain)
		return
	
	var next_variant := variants[option_chain.size()]
	
	var excl_list: VariantShaderExclusions = null
	if exclusions != null and exclusions.has(next_variant.name):
		excl_list = exclusions[next_variant.name]
		
	for option in next_variant.options():
		if excl_list != null and excl_list.options.has(option): continue
		
		# Try to reuse option chain array instead of allocating one array for each permutation.
		# Not going to be parallelizable in this state if that's ever desired however.
		option_chain.append(option)
		_compile_permutations(exclusions, option_chain)
		option_chain.remove_at(option_chain_size)

func _check_permutation_explosion_async(source: Shader, automatic: bool = false) -> ValidateStatus:
	if not automatic: return ValidateStatus.OK
	var dangerous_threshold = ProjectSettings.get_setting(
		VariantShaderEditorPlugin.SETTING_VARIANTSHADER_DANGEROUS_PERMUTATION_COUNT,
		VariantShaderEditorPlugin.SETTING_VARIANTSHADER_DANGEROUS_PERMUTATION_COUNT_DEFAULT
	)

	if permutation_count < dangerous_threshold: return ValidateStatus.OK
		
	var dialog := preload("res://addons/vshader/src/editor/warn_dialog/warn_dialog.tscn").instantiate()
	dialog.vshader_identity = source.resource_path
	dialog.permutation_count = permutation_count
	dialog.dangerous_threshold = dangerous_threshold
	EditorInterface.get_base_control().add_child(dialog)

	dialog.popup_centered()
	var which = await Promise.new([dialog.confirmed, dialog.canceled]).emitted
	var do_continue = which == dialog.confirmed
	dialog.queue_free()

	if do_continue:
		return ValidateStatus.PERMUTATION_EXPLOSION_ACCEPTED
	
	return ValidateStatus.PERMUTATION_EXPLOSION_REJECTED

func _option_map_to_chain(option_map: Dictionary[String, String], ignore_unknown_variants: bool = false) -> PackedStringArray:
	var option_chain: PackedStringArray = []
	
	var covered_option_count := 0
	for i in range(variants.size()):
		var variant := variants[i]
		var option: String
		
		if option_map.has(variant.name):
			option = option_map[variant.name]
			if not variant.has_option(option):
				push_error("VSHADER: Option '", option, "' is not valid for variant '", variant.name)
				option = variant.default_option()
			covered_option_count += 1
		else:
			option = variant.default_option()
		
		option_chain.append(option)
	
	if not ignore_unknown_variants and covered_option_count < option_map.size():
		var variant_names: Array[String] = []
		for variant in variants:
			variant_names.append(variant.name)
			
		for key in option_map.keys():
			if not variant_names.has(key):
				push_error("VSHADER: Variant '", key, "' not declared in VariantShader")
	
	return option_chain

func _try_get_cached_shader(option_chain: PackedStringArray) -> Shader:
	if option_chain.size() != variants.size():
		push_error("VSHADER: Mismatched option chain length: ", option_chain.size(), " vs ", variants.size(), " registered variant(s)")
		return null
	
	var cache_key := _option_chain_to_cache_key(option_chain)
	if _permutation_cache.has(cache_key):
		return _permutation_cache[cache_key]
	return null

func try_get_shader(options: Dictionary[String, String], ignore_unknown_variants: bool = false) -> Shader:
	var chain := _option_map_to_chain(options, ignore_unknown_variants)
	var cached_shader := _try_get_cached_shader(chain)
	return cached_shader

func get_or_compile_shader(options: Dictionary[String, String], ignore_unknown_variants: bool = false, editor_only: bool = true) -> Shader:
	var chain := _option_map_to_chain(options, ignore_unknown_variants)
	var cached_shader := _try_get_cached_shader(chain)
	if cached_shader != null: return cached_shader
	if editor_only and not Engine.is_editor_hint():
		push_error("VSHADER: Editor-only generation is enabled and an attempt was made to generate a shader ingame (option chain: ", chain, ")")
		return null
	return _generate_and_cache_shader(chain)

static func generate_from_async(shader: Shader, protect_permutation_explosion: bool, extensions: Dictionary[String, VariantShaderExtension] = {}, exclusions: Dictionary[String, VariantShaderExclusions] = {}, automatic: bool = false) -> GenerateResult:
	if shader == null:
		push_error("VSHADER: Attempted to generate cache from null shader")
		return GenerateResult.new(ValidateStatus.ERROR, null)
	var cache := VariantShaderGeneratedCache.new()
	cache._tokenize(shader, extensions)
	
	var status := ValidateStatus.OK
	
	if protect_permutation_explosion:
		status = await cache._check_permutation_explosion_async(shader, automatic)
		if status == ValidateStatus.PERMUTATION_EXPLOSION_REJECTED:
			return GenerateResult.new(status, null)
	
	cache._compile_permutations(exclusions, [])
	return GenerateResult.new(status, cache)
	
	
