extends Node
class_name VariantShaderConverter

static func create_variant_shader_async(shader_path: String) -> VariantShader:
	var binary = ProjectSettings.get_setting(VariantShaderEditorPlugin.SETTING_VARIANTSHADER_TYPE, 1)
	
	var shader = load(shader_path)
	if shader == null:
		push_error("VariantShader: failed to create VariantShader for shader at shader_path '", shader_path, "': cannot load file")
		return null
	if shader is not Shader:
		push_error("VariantShader: failed to create VariantShader for shader at shader_path '", shader_path, "': resource is not a shader")
		return null
	
	var vshader_path := shader_path.get_basename() + ".vshader" + (".res" if binary else ".tres")
	var vshader := VariantShader.new()
	await vshader.set_source_async(shader)
	
	var error := ResourceSaver.save(vshader, vshader_path)
	if error != OK:
		push_error("VariantShader: failed to create VariantShader for shader at shader_path '", shader_path, "': failed saving resource at '", vshader_path, "'")
		return null
	
	return ResourceLoader.load(vshader_path, "", ResourceLoader.CACHE_MODE_REPLACE)

static func get_or_create_variant_shader_async(shader_path: String) -> VariantShader:
	var vshader_paths := [
		shader_path.get_basename() + ".vshader.res",
		shader_path.get_basename() + ".vshader.tres"
	]
	for vshader_path in vshader_paths:
		if FileAccess.file_exists(vshader_path):
			var res := load(vshader_path)
			if res is VariantShader: return res
	return await create_variant_shader_async(shader_path)
