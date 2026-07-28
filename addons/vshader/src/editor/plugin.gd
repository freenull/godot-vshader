@tool
extends EditorPlugin
class_name VariantShaderEditorPlugin

var ctx_menu_plugin: EditorContextMenuPlugin

const SETTING_VARIANTSHADER_TYPE := "addons/vshader/context_menu_create_format"

func _enter_tree() -> void:
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
	
	ctx_menu_plugin = preload("res://addons/vshader/src/editor/ctx_menu.gd").new()
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, ctx_menu_plugin)

func _exit_tree() -> void:
	remove_context_menu_plugin(ctx_menu_plugin)
	ctx_menu_plugin = null
