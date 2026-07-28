@tool
extends EditorContextMenuPlugin

func _popup_menu(paths: PackedStringArray) -> void:
	for path in paths:
		if path.get_extension() != "gdshader":
			return
	var icon := EditorInterface.get_editor_theme().get_icon("Shader", "EditorIcons")
	add_context_menu_item("Create VariantShader", _on_create_variant_shader, icon)

func _create_variant_shader_for_path(path: String, binary: bool) -> void:
	var shader = load(path)
	if shader == null:
		push_error("VariantShader: failed to create VariantShader for shader at path '", path, "': cannot load file")
		return
	if shader is not Shader:
		push_error("VariantShader: failed to create VariantShader for shader at path '", path, "': resource is not a shader")
		return
	
	var vshader_path := path.get_basename() + ".vshader" + (".res" if binary else ".tres")
	var vshader := VariantShader.create_from_shader(shader)
	var error := ResourceSaver.save(vshader, vshader_path)
	if error != OK:
		push_error("VariantShader: failed to create VariantShader for shader at path '", path, "': failed saving resource at '", vshader_path, "'")
		return

func _on_create_variant_shader(paths: PackedStringArray) -> void:
	var binary = ProjectSettings.get_setting(VariantShaderEditorPlugin.SETTING_VARIANTSHADER_TYPE, 1)
	for path in paths:
		_create_variant_shader_for_path(path, binary)
	EditorInterface.get_resource_filesystem().scan()
		
