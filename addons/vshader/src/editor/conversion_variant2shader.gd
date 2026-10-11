extends EditorResourceConversionPlugin

func _handles(resource: Resource) -> bool:
	return resource is VariantMaterial
	
func _converts_to() -> String:
	return "ShaderMaterial"

func _convert(res: Resource) -> Resource:
	var vmat := res as VariantMaterial
	var smat := ShaderMaterial.new()
	
	if vmat.variant_shader == null or vmat.variant_shader.base_shader == null:
		return smat
	
	for uniform in vmat.shader.get_shader_uniform_list():
		var uniform_name: String = uniform["name"]
		smat.set_shader_parameter(uniform_name, vmat.get_shader_parameter(uniform_name))
	
	smat.shader = vmat.variant_shader.base_shader
	return smat
