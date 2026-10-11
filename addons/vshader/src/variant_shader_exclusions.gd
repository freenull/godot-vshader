extends Resource
class_name VariantShaderExclusions

@export
var options: Array[String]:
	set(value):
		options = value
		emit_changed()
