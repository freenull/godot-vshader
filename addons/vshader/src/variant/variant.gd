@abstract
extends Resource
class_name VariantShaderVariant

@export
var name: String

@abstract
func type_name() -> StringName

@abstract
func options() -> PackedStringArray

@abstract
func has_option(option: String) -> bool

@abstract
func default_option() -> String

@abstract
func extend(extension: VariantShaderExtension)

@abstract
func apply(tokens: Array[VariantShaderToken], option: String) -> bool

@abstract
func apply_default(tokens: Array[VariantShaderToken]) -> bool
