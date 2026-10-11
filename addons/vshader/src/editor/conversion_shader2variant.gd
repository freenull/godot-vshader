extends EditorResourceConversionPlugin

func _handles(resource: Resource) -> bool:
	return (resource is ShaderMaterial) and (resource is not VariantMaterial) and (resource.shader == null or resource.shader.resource_path != "")
	
func _converts_to() -> String:
	return "VariantMaterial"

func _convert(res: Resource) -> Resource:
	var mat := res as ShaderMaterial
	var vmat := VariantMaterial.new()
	
	if mat.shader == null:
		return vmat
	
	var vshader := await VariantShaderConverter.get_or_create_variant_shader_async(mat.shader.resource_path)
	
	for uniform in mat.shader.get_shader_uniform_list():
		var uniform_name: String = uniform["name"]
		vmat.set_shader_parameter(uniform_name, mat.get_shader_parameter(uniform_name))
	
	vmat.variant_shader = vshader
	return vmat
