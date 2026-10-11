@tool
extends EditorContextMenuPlugin

func _popup_menu(paths: PackedStringArray) -> void:
	for path in paths:
		if path.get_extension() != "gdshader":
			return
	var icon := EditorInterface.get_editor_theme().get_icon("Shader", "EditorIcons")
	add_context_menu_item("Create VariantShader", _on_create_variant_shader, icon)

func _on_create_variant_shader(paths: PackedStringArray) -> void:
	for path in paths:
		await VariantShaderConverter.create_variant_shader_async(path)
	EditorInterface.get_resource_filesystem().scan()
		
