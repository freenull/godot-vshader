@tool
extends EditorPlugin
class_name VariantShaderEditorPlugin

var ctx_menu_plugin: EditorContextMenuPlugin
var shader_material_conversion_plugin: EditorResourceConversionPlugin
var variant_material_conversion_plugin: EditorResourceConversionPlugin

const SETTING_VARIANTSHADER_TYPE := "addons/vshader/context_menu_create_format"
const SETTING_VARIANTSHADER_DANGEROUS_PERMUTATION_COUNT := "addons/vshader/dangerous_permutation_count"
const SETTING_VARIANTSHADER_DANGEROUS_PERMUTATION_COUNT_DEFAULT := 1024

func _configure_settings() -> void:
	if not ProjectSettings.has_setting(SETTING_VARIANTSHADER_TYPE):
		ProjectSettings.set_setting(SETTING_VARIANTSHADER_TYPE, 1)
	ProjectSettings.set_initial_value(SETTING_VARIANTSHADER_TYPE, 1)
	ProjectSettings.add_property_info({
		"name": SETTING_VARIANTSHADER_TYPE,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Text (.vshader.tres),Binary (.vshader.res)"
	})
	ProjectSettings.set_as_basic(SETTING_VARIANTSHADER_TYPE, true)
	
	if not ProjectSettings.has_setting(SETTING_VARIANTSHADER_DANGEROUS_PERMUTATION_COUNT):
		ProjectSettings.set_setting(
			SETTING_VARIANTSHADER_DANGEROUS_PERMUTATION_COUNT,
			SETTING_VARIANTSHADER_DANGEROUS_PERMUTATION_COUNT_DEFAULT
		)
	ProjectSettings.set_initial_value(
		SETTING_VARIANTSHADER_DANGEROUS_PERMUTATION_COUNT,
		SETTING_VARIANTSHADER_DANGEROUS_PERMUTATION_COUNT_DEFAULT
	)
	ProjectSettings.add_property_info({
		"name": SETTING_VARIANTSHADER_DANGEROUS_PERMUTATION_COUNT,
		"type": TYPE_INT
	})
	ProjectSettings.set_as_basic(SETTING_VARIANTSHADER_DANGEROUS_PERMUTATION_COUNT, true)

func _enter_tree() -> void:
	_configure_settings()
	
	ctx_menu_plugin = preload("res://addons/vshader/src/editor/ctx_menu.gd").new()
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, ctx_menu_plugin)
	
	shader_material_conversion_plugin = preload("res://addons/vshader/src/editor/conversion_shader2variant.gd").new()
	add_resource_conversion_plugin(shader_material_conversion_plugin)
	
	variant_material_conversion_plugin = preload("res://addons/vshader/src/editor/conversion_variant2shader.gd").new()
	add_resource_conversion_plugin(variant_material_conversion_plugin)

func _exit_tree() -> void:
	remove_resource_conversion_plugin(variant_material_conversion_plugin)
	remove_resource_conversion_plugin(shader_material_conversion_plugin)
	remove_context_menu_plugin(ctx_menu_plugin)
	ctx_menu_plugin = null
