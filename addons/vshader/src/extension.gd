@tool
extends Resource
class_name VariantShaderExtension

@export
var entries: Array[String] = []:
	set(value):
		entries = value
		emit_changed()
