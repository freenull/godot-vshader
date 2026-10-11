extends VariantShaderVariant
class_name VariantShaderVariantEnumLike

enum Kind { ENUM, VALUE }

@export
var kind: Kind = Kind.ENUM

@export
var values: Dictionary[String, int]

@export
var default_option_name: String

func type_name() -> StringName:
	match kind:
		Kind.ENUM: return &"enum"
		Kind.VALUE: return &"int"
		_: return &"int"

func options() -> PackedStringArray:
	return values.keys()

func has_option(option: String) -> bool:
	return values.has(option)

func default_option() -> String:
	return default_option_name

func _remove_existing_toplevel_defines(tokens: Array[VariantShaderToken]):
	var indices_to_remove: Array[int] = []
	var preprocessor_branch_depth := 0
	
	var token_count := tokens.size()
	
	for i in range(token_count):
		var token := tokens[i]
		if token.type == VariantShaderToken.TokenType.PREPROCESSOR_DIRECTIVE_BEGIN:
			if token.value in ["if", "ifdef", "ifndef"]:
				preprocessor_branch_depth += 1
			elif token.value == "endif":
				preprocessor_branch_depth -= 1
			elif token.value == "define" and preprocessor_branch_depth == 0 and i + 1 < token_count:
				var name_token := tokens[i + 1]
				if name_token.type == VariantShaderToken.TokenType.IDENTIFIER and name_token.value == name:
					indices_to_remove.append(i)
					indices_to_remove.append(i + 1)
					for j in range(i + 2, token_count):
						indices_to_remove.append(j)
						if tokens[j].type == VariantShaderToken.TokenType.PREPROCESSOR_DIRECTIVE_END:
							break
	
	for i in range(indices_to_remove.size() - 1, -1, -1):
		tokens.remove_at(indices_to_remove[i])
		
		

func _prepend_preprocessor(tokens: Array[VariantShaderToken], directive: String, name: String, value: String = ""):
	tokens.insert(0, VariantShaderToken.create(
		VariantShaderToken.TokenType.PREPROCESSOR_DIRECTIVE_BEGIN,
		directive
	))
	
	tokens.insert(1, VariantShaderToken.create(
		VariantShaderToken.TokenType.IDENTIFIER,
		name
	))
	
	if value != "":
		tokens.insert(2, VariantShaderToken.create(
			VariantShaderToken.TokenType.OTHER,
			value
		))
	
	tokens.insert(3 if value != "" else 2, VariantShaderToken.create(
		VariantShaderToken.TokenType.PREPROCESSOR_DIRECTIVE_END
	))

func _prepend_define(tokens: Array[VariantShaderToken], option: String):
	var macro_name := str(name, "_", option) if kind == Kind.ENUM else name
	var value := "" if kind == Kind.ENUM else values[option]
	_prepend_preprocessor(tokens, "define", macro_name, str(value))

func extend(extension: VariantShaderExtension):
	for entry in extension.entries:
		var elems := entry.split("=", true, 1)
		if elems.size() != 2:
			push_warning("VSHADER: Invalid extension entry for enum-like variant: '", entry, "' (skipped)")
			continue
		
		var key := elems[0]
		var value := elems[1]
		if values.has(key):
			push_warning("VSHADER: Enum-like variant shader extension key '", key, "' is a duplicate of existing entry (skipped)")
			continue
		if not value.is_valid_int():
			push_warning("VSHADER: Enum-like variant shader extension '", key, "' contains invalid value '", value, "' (skipped)")
			continue
			
		values[key] = int(value)

func apply(tokens: Array[VariantShaderToken], option: String) -> bool:
	if not values.has(option):
		push_error("VSHADER: Cannot apply enum variant: option '", option, "' not declared")
		return apply_default(tokens)
	
	_remove_existing_toplevel_defines(tokens)
	_prepend_define(tokens, option)
	return true

func apply_default(tokens: Array[VariantShaderToken]) -> bool:
	_remove_existing_toplevel_defines(tokens)
	_prepend_define(tokens, default_option_name)
	return true
