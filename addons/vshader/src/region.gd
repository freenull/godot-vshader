@tool
extends Resource
class_name VariantShaderRegion

@export
var start_row: int
@export
var end_row: int
@export
var start_col: int
@export
var end_col: int

static func create_from_point(row: int, col: int) -> VariantShaderRegion: 
	var r := VariantShaderRegion.new()
	r.set_to_point(row, col)
	return r

static func create_from_range(start_row: int, start_col: int, end_row: int, end_col: int) -> VariantShaderRegion:
	var r := VariantShaderRegion.new()
	r.set_to_range(start_row, start_col, end_row, end_col)
	return r

func _to_string() -> String:
	if start_row == end_row:
		if start_col == end_col:
			return str(start_row, ":", start_col)
		return str(start_row, ":", start_col, "-", end_col)
	return str(start_row, ":", start_col, "-", end_row, ":", end_col)

func extend_to(to: VariantShaderRegion):
	end_row = to.end_row
	end_col = to.end_col

func duplicate(deep: bool = false) -> VariantShaderRegion:
	var r := VariantShaderRegion.new()
	r.start_col = start_col
	r.start_row = start_row
	r.end_col = end_col
	r.end_row = end_row
	return r

func end_point() -> VariantShaderRegion:
	var r := VariantShaderRegion.new()
	r.set_to_point(end_row, end_col)
	return r

func set_to_point(row: int, col: int):
	start_row = row
	end_row = row
	start_col = col
	end_col = col

func set_to_range(start_row: int, start_col: int, end_row: int, end_col: int):
	self.start_row = start_row
	self.start_col = start_col
	self.end_row = end_row
	self.end_col = end_col
