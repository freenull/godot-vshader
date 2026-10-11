extends Node
class_name VariantShaderTokenizer

enum TokenizerMode { NORMAL, PREPROCESSOR_DIRECTIVE_INCLUDE, PREPROCESSOR_DIRECTIVE_GENERIC, VSHADER_DIRECTIVE }
enum TokenizerModeStringSupport { DOUBLE_QUOTED, INCLUDE_STYLE }

static func tokenizer_mode_supports_strings(mode: TokenizerMode, support: TokenizerModeStringSupport) -> bool:
	if mode == TokenizerMode.PREPROCESSOR_DIRECTIVE_INCLUDE: return true
	if mode == TokenizerMode.VSHADER_DIRECTIVE and support == TokenizerModeStringSupport.DOUBLE_QUOTED:
		return true
	return false

class TokenCompilerSettings:
	var skip_vshader_directives: bool = false
	var skip_comments: bool = false
	var auto_detect_line_comments: bool = true
	
	func should_skip_token(token: VariantShaderToken, mode: TokenizerMode):
		if skip_vshader_directives:
			if mode == TokenizerMode.VSHADER_DIRECTIVE: return true
			if token.type == VariantShaderToken.TokenType.VSHADER_DIRECTIVE_BEGIN: return true
		
		if skip_comments and token.type == VariantShaderToken.TokenType.COMMENT: return true
		
		return false

class TokenCompiler:
	var code: String = ""
	var mode: TokenizerMode = TokenizerMode.NORMAL
	var settings: TokenCompilerSettings
	
	func _init(settings: TokenCompilerSettings = null):
		if settings == null:
			self.settings = TokenCompilerSettings.new()
		else:
			self.settings = settings
	
	func compile(token: VariantShaderToken, prev_token: VariantShaderToken = null, next_token: VariantShaderToken = null):
		if not settings.should_skip_token(token, mode):
			if mode != TokenizerMode.NORMAL and (prev_token == null or (not prev_token.breaks_line() and prev_token.has_content())):
				code += " "
			
			if token.type == VariantShaderToken.TokenType.COMMENT and settings.auto_detect_line_comments and next_token != null and next_token.type == VariantShaderToken.TokenType.LINE_BREAK:
				code += "// " + token.value
			else:
				code += token.compile()
				if token.breaks_line(): code += "\n"
		
		if token.type == VariantShaderToken.TokenType.VSHADER_DIRECTIVE_BEGIN:
			mode = TokenizerMode.VSHADER_DIRECTIVE
		elif token.type == VariantShaderToken.TokenType.PREPROCESSOR_DIRECTIVE_BEGIN:
			mode = TokenizerMode.PREPROCESSOR_DIRECTIVE_GENERIC
		elif token.type in [VariantShaderToken.TokenType.EOF, VariantShaderToken.TokenType.VSHADER_DIRECTIVE_END, VariantShaderToken.TokenType.PREPROCESSOR_DIRECTIVE_END]:
			mode = TokenizerMode.NORMAL
		
	func compile_all(tokens: Array[VariantShaderToken]) -> String:
		var tokens_size := tokens.size()
		for i in range(tokens_size):
			var prev_token: VariantShaderToken = null if i == 0 else tokens[i - 1]
			var next_token: VariantShaderToken = null if i + 1 >= tokens_size else tokens[i + 1]
			compile(tokens[i], prev_token, next_token)
		return code

const DIRECTIVES: Array[String] = ["variant", "module", "endmodule"]

var data: String
var data_len: int
var cur_idx: int = 0
var region: VariantShaderRegion
var mode: TokenizerMode = TokenizerMode.NORMAL
var is_first_token_of_line: bool = true
var _peeked_char: String = ""
var _peeked_token: VariantShaderToken = null

func _init(data: String):
	data_len = data.length()
	self.data = data
	region = VariantShaderRegion.create_from_point(1, 0)

func _next_char() -> String:
	if cur_idx >= data_len:
		return ""
		
	var c := data[cur_idx]
	cur_idx += 1
	
	if c == "\n":
		region.end_row += 1
		region.end_col = 0
	else:
		region.end_col += 1
	region.start_row = region.end_row
	region.start_col = region.end_col
	
	if c == "\\":
		if cur_idx < data_len and data[cur_idx] == "\n":
			cur_idx += 1
		elif cur_idx + 1 < data_len and data[cur_idx] == "\r" and data[cur_idx + 1] == "\n":
			cur_idx += 2
		else:
			return c
		
		return " "
	
	return c
	
func _peek_char() -> String:
	if cur_idx >= data_len:
		return ""
	
	var c = data[cur_idx]
	
	if c == "\\":
		if cur_idx + 1 < data_len and data[cur_idx + 1] == "\n":
			return " "
		elif cur_idx + 2 < data_len and data[cur_idx + 1] == "\r" and data[cur_idx + 2] == "\n":
			return " "
	
	return c

func _is_whitespace(c: String):
	return _is_whitespace_except_newline(c) or c == "\n"

func _is_whitespace_except_newline(c: String):
	return c == " " or c == "\t" or c == "\r"

func _is_eof(c: String):
	return c == ""

func _read_whitespace() -> VariantShaderToken:
	var region := self.region.end_point()
	
	while true:
		var c := _peek_char()
		if not _is_whitespace_except_newline(c):
			break
		_next_char()
	
	region.extend_to(self.region)
	
	return VariantShaderToken.create(VariantShaderToken.TokenType.WHITESPACE, "", region)

func _skip_whitespace():
	while true:
		var c := _peek_char()
		if not _is_whitespace(c):
			break
		_next_char()

func _is_token_boundary(c: String):
	return _is_whitespace(c) or _is_eof(c) or c in ["{", "}", ",", "="]

const CHAR_0 := ord("0")
const CHAR_9 := ord("9")
const CHAR_a := ord("a")
const CHAR_z := ord("z")
const CHAR_A := ord("A")
const CHAR_Z := ord("Z")
const CHAR_UNDER := ord("_")

func _read_identifier(start_char: String) -> VariantShaderToken:
	var region := self.region.end_point()
	var first := true
	var literal := start_char
	while true:
		var c := _peek_char()
		if c == "":
			break
		var o := ord(c)
		
		if not (o >= CHAR_a and o <= CHAR_z) and not (o >= CHAR_A and o <= CHAR_Z) and o != CHAR_UNDER:
			if first: break
			if not (o >= CHAR_0 and o <= CHAR_9): break
		first = false
		literal += c
		_next_char()
	
	region.extend_to(self.region)
	return VariantShaderToken.create(VariantShaderToken.TokenType.IDENTIFIER, literal, region)

func _read_other(start_char: String) -> VariantShaderToken:
	var region := self.region.end_point()
	var content := start_char
	while true:
		var c := _peek_char()
		if _is_token_boundary(c):
			break
		_next_char()
		content += c
	
	region.extend_to(self.region)
	return VariantShaderToken.create(VariantShaderToken.TokenType.OTHER, content, region)

func _read_line_comment_or_directive(region: VariantShaderRegion) -> VariantShaderToken:
	var content := ""
	var cached_whitespace_sequence := ""
	var has_non_whitespace_chars := false
	var is_directive := false
	while true:
		var c := _peek_char()
		if c == "\n" or _is_eof(c):
			break
		_next_char()
		
		if _is_whitespace_except_newline(c):
			if is_directive:
				if DIRECTIVES.has(content): break
				content = "@" + content
				is_directive = false
			if has_non_whitespace_chars:
				cached_whitespace_sequence += c
		else:
			if content.length() == 0 and c == "@":
				is_directive = true
			else:
				has_non_whitespace_chars = true
				content += cached_whitespace_sequence + c
				cached_whitespace_sequence = ""
		region.extend_to(self.region)
	
	if is_directive:
		return VariantShaderToken.create(VariantShaderToken.TokenType.VSHADER_DIRECTIVE_BEGIN, content, region)
	
	return VariantShaderToken.create(VariantShaderToken.TokenType.COMMENT, content, region)

func _read_block_comment(region: VariantShaderRegion) -> VariantShaderToken:
	var content := ""
	var unterminated := false
	while true:
		var c := _next_char()
		if c == "*":
			var n := _next_char()
			if n == "/":
				break
		elif _is_eof(c):
			unterminated = true
			break
		content += c
	
	if unterminated:
		push_error("VariantShaderTokenizer: unterminated block comment at ", region)
	region.extend_to(self.region)
	return VariantShaderToken.create(VariantShaderToken.TokenType.COMMENT, content, region)

func _read_quoted_string(region: VariantShaderRegion, term_char: String, allow_escapes: bool = true):
	var escape := false
	var s := ""
	
	while true:
		var c := _next_char()
		if c == "":
			region.extend_to(self.region)
			push_error("VariantShaderTokenizer: unterminated string at ", region)
			
		if escape:
			if   c == "n": c = "\n"
			elif c == "t": c = "\t"
			elif c == "v": c = "\v"
			elif c == "a": c = "\a"
			escape = false
		else:
			if c == "\\" and allow_escapes:
				escape = true
				continue
			elif c == term_char:
				break
				
		s += c
	
	region.extend_to(self.region)
	return VariantShaderToken.create(VariantShaderToken.TokenType.STRING, s, region)

func peek_token() -> VariantShaderToken:
	if _peeked_token != null:
		return _peeked_token
	
	_peeked_token = next_token()
	return _peeked_token
	
func next_token() -> VariantShaderToken:
	if _peeked_token != null:
		var tok := _peeked_token
		_peeked_token = null
		return tok
		
	var c := _next_char()
	
	if c == "#" and is_first_token_of_line:
		_skip_whitespace()
		var directive := self._read_identifier("").value
		if directive == "include":
			mode = TokenizerMode.PREPROCESSOR_DIRECTIVE_INCLUDE
		else:
			mode = TokenizerMode.PREPROCESSOR_DIRECTIVE_GENERIC
		return VariantShaderToken.create(VariantShaderToken.TokenType.PREPROCESSOR_DIRECTIVE_BEGIN, directive, self.region)
	
	if not _is_whitespace(c):
		is_first_token_of_line = false
	
	if c == "/":
		var line_comment_region := self.region.end_point()
		var p := _peek_char()
		if p == "/":
			_next_char()
			var comment_or_directive := _read_line_comment_or_directive(line_comment_region)
			if comment_or_directive.type == VariantShaderToken.TokenType.VSHADER_DIRECTIVE_BEGIN:
				mode = TokenizerMode.VSHADER_DIRECTIVE
			is_first_token_of_line = true
			return comment_or_directive
		elif p == "*":
			_next_char()
			return _read_block_comment(line_comment_region)
		else:
			return VariantShaderToken.create(VariantShaderToken.TokenType.OTHER, c, self.region)
	elif c == "\n":
		is_first_token_of_line = true
		match mode:
			TokenizerMode.PREPROCESSOR_DIRECTIVE_GENERIC, TokenizerMode.PREPROCESSOR_DIRECTIVE_INCLUDE:
				mode = TokenizerMode.NORMAL
				return VariantShaderToken.create(VariantShaderToken.TokenType.PREPROCESSOR_DIRECTIVE_END, "", self.region)
			TokenizerMode.VSHADER_DIRECTIVE:
				mode = TokenizerMode.NORMAL
				return VariantShaderToken.create(VariantShaderToken.TokenType.VSHADER_DIRECTIVE_END, "", self.region)
			_:
				return VariantShaderToken.create(VariantShaderToken.TokenType.LINE_BREAK, "", self.region)
	elif _is_whitespace_except_newline(c):
		if mode == TokenizerMode.NORMAL:
			return _read_whitespace()
		_skip_whitespace()
		return next_token()
	elif c.is_valid_ascii_identifier():
		return _read_identifier(c)
	elif tokenizer_mode_supports_strings(mode, TokenizerModeStringSupport.INCLUDE_STYLE) and c == "<":
		return _read_quoted_string(region, ">", false)
	elif tokenizer_mode_supports_strings(mode, TokenizerModeStringSupport.DOUBLE_QUOTED) and c == "\"":
		return _read_quoted_string(region, "\"", true)
	elif c == "{":
		return VariantShaderToken.create(VariantShaderToken.TokenType.BRACE_OPEN, "{", self.region)
	elif c == "}":
		return VariantShaderToken.create(VariantShaderToken.TokenType.BRACE_CLOSE, "}", self.region)
	elif c == ",":
		return VariantShaderToken.create(VariantShaderToken.TokenType.COMMA, ",", self.region)
	elif c == "=":
		return VariantShaderToken.create(VariantShaderToken.TokenType.ASSIGN, "=", self.region)
	elif not _is_token_boundary(c):
		return _read_other(c)
	elif _is_eof(c):
		return VariantShaderToken.create(VariantShaderToken.TokenType.EOF, "", self.region.end_point())
	push_warning("Unknown token at ", self.region, ": ", c)
	return VariantShaderToken.create(VariantShaderToken.TokenType.EOF, "", self.region.end_point())
	
	
	
