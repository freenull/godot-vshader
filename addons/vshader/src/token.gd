@tool
extends Resource
class_name VariantShaderToken

enum TokenType { EOF, WHITESPACE, LINE_BREAK, COMMENT, STRING, IDENTIFIER, BRACE_OPEN, BRACE_CLOSE, COMMA, ASSIGN, VSHADER_DIRECTIVE_BEGIN, VSHADER_DIRECTIVE_END, PREPROCESSOR_DIRECTIVE_BEGIN, PREPROCESSOR_DIRECTIVE_END, OTHER }

@export
var type: TokenType
@export
var value: String
@export
var region: VariantShaderRegion

static func create(type: TokenType, value: String = "", region: VariantShaderRegion = null) -> VariantShaderToken:
	var tok := VariantShaderToken.new()
	tok.type = type
	tok.value = value
	tok.region = region
	return tok

func _to_string() -> String:
	var type_name := "<unknown>"
	var key := TokenType.find_key(type)
	if key != null: type_name = key
	if region == null:
		return str("[?:?] ", key, " \"", value, "\"")
	else:
		return str("[", region, "] ", key, " \"", value, "\"")

func _escape_string(s: String) -> String:
	var escaped := ""
	for c in s:
		match c:
			"\"": escaped += "\\\""
			"\n": escaped += "\\n"
			"\t": escaped += "\\t"
			"\v": escaped += "\\v"
			"\a": escaped += "\\a"
			_:    escaped += c
	return "\"" + escaped + "\""

func has_content() -> bool:
	return value != ""

func breaks_line() -> bool:
	return type in [TokenType.LINE_BREAK, TokenType.VSHADER_DIRECTIVE_END, TokenType.PREPROCESSOR_DIRECTIVE_END]

func compile() -> String:
	match type:
		TokenType.EOF: return ""
		TokenType.WHITESPACE: return " "
		TokenType.LINE_BREAK, TokenType.VSHADER_DIRECTIVE_END, TokenType.PREPROCESSOR_DIRECTIVE_END: return ""
		TokenType.COMMENT: return "/* " + value + " */"
		TokenType.IDENTIFIER: return value
		TokenType.VSHADER_DIRECTIVE_BEGIN: return "// @" + value
		TokenType.OTHER: return value
		TokenType.PREPROCESSOR_DIRECTIVE_BEGIN: return "#" + value
		TokenType.STRING: return _escape_string(value)
		TokenType.BRACE_OPEN: return "{"
		TokenType.BRACE_CLOSE: return "}"
		TokenType.COMMA: return ","
		TokenType.ASSIGN: return "="
	push_error("VariantShaderTokenizer: invalid token type for compile(): ", type)
	return ""

func type_name() -> String:
	var key := TokenType.find_key(type)
	if key == null: return "<unknown>"
	return key
