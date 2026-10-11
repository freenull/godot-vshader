@tool
extends ConfirmationDialog

func warning_message() -> String:
	return str(
		"[p]",
		"The source code of this variant-enabled shader declares [b]{permutation_count}[/b] possible permutations of variant options.",
		"[/p][br]",
		"[p]",
		"Pre-filling the entire shader cache requires generating {permutation_count} [code]Shader[/code] instances, each with a separate copy of the source code. ",
		"Each of these shaders will have to be loaded along with the [code]VariantShader[/code] resource in-game. ",
		"Large caches like this may have a significant effect on loading times, RAM usage and disk usage.",
		"[/p][br]",
		"[p]",
		"[b]Are you sure you want to continue?[/b][br]",
		"Pressing [i]Cancel[/i] will suspend recompilation until you re-enable it or recompile manually.[br]Pressing [i]OK[/i] will continue generation and disable this confirmation dialog.[br]",
		"[/p][br]",
		"[p]",
		"[b]Note:[/b] You can use the [code]exclusions[/code] property to narrow down the permutation set.",
		"[/p]",
	)

func note_message() -> String:
	return str(
		"[p]The dangerous threshold is configured as {dangerous_threshold} through the [code]addons/vshader/dangerous_permutation_count[/code] project setting. ",
		"You can control whether this message appears through the [code]auto_recompilation_mode[/code] property on the resource.[/p][br]",
		"[p]If you select [i]Cancel[/i], shaders with specific variant options can still be generated on demand.[/p]"
	)

@export
var vshader_identity: String = "<unknown>":
	set(value):
		vshader_identity = value
		_update_text()
		
@export 
var permutation_count: int = 1:
	set(value):
		permutation_count = value
		_update_text()
		
@export
var dangerous_threshold: int = 1:
	set(value):
		dangerous_threshold = value
		_update_text()

func _apply_placeholders(msg: String) -> String:
	msg = msg.replace("{permutation_count}", str(permutation_count))
	msg = msg.replace("{dangerous_threshold}", str(dangerous_threshold))
	return msg

func _update_text():
	if %WarningTextBox == null: return
	if vshader_identity == "":
		%VariantShaderIdentity.hide()
	else:
		%VariantShaderIdentity.text = "[code]" + vshader_identity + "[/code]"
		%VariantShaderIdentity.show()
	%WarningTextBox.text = _apply_placeholders(warning_message())
	%NoteTextBox.text = _apply_placeholders(note_message())
	

func _ready():
	_update_text()
