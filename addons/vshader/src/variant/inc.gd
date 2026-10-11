extends VariantShaderVariant
class_name VariantShaderVariantInc

const STUB_OPTION_NAME := "<stub>"

@export_file("*.gdshaderinc")
var inc_paths: Array[String] = []

@export
var base_dir: String = ""

@export_file("*.gdshaderinc")
var stub_path: String = ""

func type_name() -> StringName:
	return &"inc"

func options() -> PackedStringArray:
	var ary := PackedStringArray(inc_paths)
	ary.insert(0, STUB_OPTION_NAME)
	return ary

func _is_valid_inc_path(path: String) -> bool:
	return path.is_absolute_path() and path.ends_with(".gdshaderinc")

func has_option(option: String) -> bool:
	if option == STUB_OPTION_NAME: return true
	return _is_valid_inc_path(option)

func default_option() -> String:
	return STUB_OPTION_NAME

func _replace_inc(tokens: Array[VariantShaderToken], new_path: String):
	var normalized_stub_path: String
	if stub_path.is_absolute_path():
		normalized_stub_path = stub_path.simplify_path()
	else:
		normalized_stub_path = base_dir.path_join(stub_path).simplify_path()
	
	if not _is_valid_inc_path(new_path):
		push_error("VSHADER: Not a valid path for include variant '", name, "': ", new_path)
		return
		
	var normalized_new_path := new_path.simplify_path()
	
	var token_count := tokens.size()
	for i in range(token_count):
		var token := tokens[i]
		
		if token.type != VariantShaderToken.TokenType.PREPROCESSOR_DIRECTIVE_BEGIN or token.value != "include":
			continue
		
		i += 1
		if i >= token_count: break
		token = tokens[i]
		var path_token_idx := i
		var path_token := token
		
		if token.type != VariantShaderToken.TokenType.STRING:
			continue
		
		i += 1
		if i >= token_count: break
		token = tokens[i]
		
		if token.type != VariantShaderToken.TokenType.PREPROCESSOR_DIRECTIVE_END:
			continue
			
		var raw_path := path_token.value
		if not raw_path.is_absolute_path():
			raw_path = base_dir.path_join(raw_path)
		
		var normalized_src_path := raw_path.simplify_path()
		if normalized_src_path != normalized_stub_path:
			continue
		
		var new_path_token := VariantShaderToken.create(
			VariantShaderToken.TokenType.STRING, normalized_new_path
		)
			
		tokens[path_token_idx] = new_path_token

func extend(extension: VariantShaderExtension):
	for entry in extension.entries:
		if not _is_valid_inc_path(entry):
			push_warning("VSHADER: Inc variant extension entry '", entry, "' is not a valid absolute *.gdshaderinc path (skipped)")
			continue
		
		if inc_paths.has(entry):
			push_warning("VSHADER: Inc variant extension entry '", entry, "' is a duplicate of existing entry (skipped)")
			continue
		
		inc_paths.append(entry)

func apply(tokens: Array[VariantShaderToken], option: String) -> bool:
	if option == STUB_OPTION_NAME: return true
	_replace_inc(tokens, option)
	return true

func apply_default(tokens: Array[VariantShaderToken]) -> bool:
	return true
