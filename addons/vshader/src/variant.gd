extends Resource
class_name VariantShaderVariant

@export
var name: String

@export
var values: PackedStringArray = []

func get_value(key: String) -> int:
	var idx := 0
	for v in values:
		if v == key:
			return idx
		idx += 1
	return -1

func get_key(value: int) -> String:
	if value < 0 or value >= values.size(): return ""
	return values[value]
