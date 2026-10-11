@tool
extends ShaderMaterial
class_name VariantMaterial

func _on_variant_shader_changed():
	if variant_shader != null:
		_update_shader()

@export_storage
var _variant_params: Dictionary[String, String] = {}

## VariantShader instance. It is recommended to use a VariantShader saved as a resource,
## preferably a binary one, otherwise large amounts of shader permutations will inflate
## the size of this material instance or the scene in which it is used.
@export
var variant_shader: VariantShader:
	set(value):
		if variant_shader != null:
			variant_shader.changed.disconnect(_on_variant_shader_changed)
		if variant_shader != value:
			shader = null
		variant_shader = value
		_on_variant_shader_changed()
		if variant_shader != null:
			variant_shader.changed.connect(_on_variant_shader_changed)

func _update_shader():
	if variant_shader == null: return
	shader = variant_shader.try_get_shader(_variant_params, true)
	notify_property_list_changed()

func _validate_property(property: Dictionary) -> void:
	if property.name == "shader":
		property.usage &= ~PROPERTY_USAGE_EDITOR

func get_shader_variant(param: StringName) -> String:
	if variant_shader == null: return ""
	var variant := variant_shader.try_get_variant(param)
	if variant == null: return ""
	if not _variant_params.has(param):
		return variant.get_key(0)
	return _variant_params[param]

func set_shader_variant(param: StringName, value: String) -> void:
	if variant_shader == null:
		push_warning("VariantMaterial: no VariantShader associated before set_shader_variant")
	_variant_params[param] = value
	_update_shader()
	
func _get_property_list() -> Array[Dictionary]:
	var props := []
	
	if variant_shader == null or variant_shader.cache == null:
		return props
	
	for variant in variant_shader.cache.variants:
		var hint_string := ""
		var first := true
		for option in variant.options():
			if variant_shader.is_excluded(variant, option):
				continue
			if not first:
				hint_string += ","
			first = false
			hint_string += option
			
		props.append({
			"name": "shader_variants/" + variant.name.to_lower(),
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": hint_string
		})
	
	props.append({
		"name": "active_shader",
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "Shader",
		"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
	})
	
	return props

func _get(property: StringName) -> Variant:
	if property == "active_shader":
		return shader
	if not property.begins_with("shader_variants/"):
		return null
	var variant_key := property.substr("shader_variants/".length()).to_upper()
	var value := _variant_params.get(variant_key)
	if value != null or variant_shader == null:
		return value
	
	var variant := variant_shader.try_get_variant(variant_key)
	if variant == null:
		return null
	
	return variant.default_option()

func _set(property: StringName, value: Variant) -> bool:
	if not property.begins_with("shader_variants/"):
		return false
	if value is not String:
		push_warning("VariantMaterial: shader variants can only be set to String objects")
		return false
	
	var variant_key := property.substr("shader_variants/".length()).to_upper()
	_variant_params[variant_key] = value
	_update_shader()
	return true
