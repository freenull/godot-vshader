# Godot VariantShader

Minimalistic shader variant (AKA shader feature, shader switch parameter) support for Godot 4.7+ implemented in GDScript. 

## Installation

* Copy `addons/vshader` to the `addons` directory of your project.
* Open _Project Settings_, go to the _Plugins_ section and enable _Variant Shaders_.

## Usage

Variants are essentially 1+ element enums. They can have any number of possible values, although keep combinatorial explosion in mind (see later sections). The default value of a variant is always its first option.

### Exporting variants from shaders

Variant definitions are placed in single-line comments according to the following syntax:

```c
// @variant NAME DEFAULT_OPTION [OTHER_OPTIONS...]
```

For example:

```c
// @variant DEBUG OFF ON
// @variant IMPLEMENTATION DEFAULT SOME_OTHER_THING SOMETHING_ELSE
```

This exports two variant enums for a total of 6 combinations.

Currently, variant definitions can only be placed in `*.gdshader` files (definitions inside `*.gdshaderinc` will be ignored).

### Variant generation

Variant generation involves generating all possible permutations of all variants, and then generating a shader for each permutation where the active value of each variant is defined as a unique macro in the format `VARIANT_OPTION`.

Unique variant and option combinations that map to the same macro name (e.g. variant `A_B`, option `C` and variant `A`, option `B_C`) are reported as warnings during generation.

Preprocessor instructions like `#if` or `#include` are not processed when generating shader permutations. 

For the shader below:

```
// @variant DEBUG OFF ON
shader_type spatial;
void vertex() {}
```

two versions are generated:

* ```
  #define DEBUG_OFF
  // @variant DEBUG OFF ON
  void vertex() {}
  ```
* ```
  #define DEBUG_ON
  // @variant DEBUG OFF ON
  void vertex() {}
  ```

### Using variants in shaders

Detecting variant options in shaders is as simple as checking for `VARIANT_OPTION` macros with `#ifdef`:

```
// @variant DEBUG OFF ON

shader_type spatial;
void vertex() { /* ... */ }
void fragment() {
  // ...

#ifdef DEBUG_ON
  ALBEDO.r = 1.0;
#endif
}
```

`#ifdef` was chosen as opposed to constructs like `#if DEBUG == OFF` or `#if DEBUG` because Godot raises errors for undefined macros in `#if`.

The builtin Godot shader editor will gray out contents of `#ifdef` blocks if the macro isn't defined within the same source code file and there is no way to give the editor a list of macros to consider predefined. If you need syntax highlighting in those blocks and can't use a different editor, just temporarily place a `#define` of that macro somewhere earlier.

### Conditional uniforms

You can conditionally include or exclude any code. It may be obvious, but do note that you can include or exclude uniforms based on variants:

```
// @variant MODE FLAT HEIGHTMAP

#ifdef MODE_HEIGHTMAP
uniform sampler2D heightmap;
#endif

// ...
```

Shader materials store uniforms in an internal dictionary disconnected from the actual shader, so the values of your uniforms will not be lost when swapping between variants as long as they have the same types or unique names.

### Creating variant shaders

`VariantShader` is a resource that contains a reference to a `Shader` object (the reference from which shaders are generated) and an internal cache of generated shaders. `VariantShader` **does not** extend `Shader` and cannot be used as a replacement for `Shader` objects.

You can create this resource manually using the inspector. Assigning the `base_shader` property will automatically regenerate shader permutations. Alternatively, you can right click on a `.gdshader` file and use the _Create VariantShader_ context menu option to automatically create a `.vshader.res` file next to the shader file. The `addons/vshader/context_menu_create_format` project setting can be changed to generate `.vshader.tres` files instead (although `.res` is recommended due to the large amount of `Shader` objects and duplicated code stored in the file).

### Using variant shaders in materials

`VariantMaterial` is a resource that represents a material with variant shader functionality. Unlike `VariantShader`, `VariantMaterial` **does extend** `ShaderMaterial` and can be assigned anywhere where a `ShaderMaterial` is expected.

`VariantShader` resources can be assigned to the `variant_shader` property of `VariantMaterial`. This automatically picks the generated permutation representing all default options of variants and sets it as the actual rendered `shader`.

If the `VariantShader` exposes any variants, they will be displayed in a similar manner to `Shader Parameters` under the `Shader Variants` group as enums. Changes to variant options automatically swap the active generated shader of the material. The `Shader Parameters` group will also appear in the inspector, and will respond to changes in the `Shader Variants` group.

`VariantMaterial` contains two functions that mirror the `ShaderMaterial.{set,get}_shader_parameter` interface for variants:
* `set_shader_variant(param: StringName, value: String)`
* `get_shader_variant(param: StringName) -> String`

The semantics of this interface slightly differ from the shader parameter analogue:
* Only strings (representing keys as defined in `//@variant ...` declarations) are allowed as values.
* Whereas `get_shader_parameter` will return `null` if `set_shader_parameter` hadn't been previously called even if the associated uniform has an active default, shader variant functions will always the return the real active default in such case.
  * The only exceptions are if `visual_shader` is unset or if the shader does not export a `param` variant. In those cases, an empty string will be returned.

### Masking variant options

You can exclude certain variant options through the `VariantShader` `exclude_options` property. This may be useful if you didn't write the shader and would rather not modify it directly.

The property is an array of strings in the following format:
* `DEBUG=OFF` - all permutations where the `DEBUG` variant takes the `OFF` value will be excluded
* `DEBUG=*` - all permutations where the `DEBUG` takes a non-default value will be excluded

Keep in mind that if you exclude all possible options of a variant, no permutations can and will be generated (because every permutation will contain an excluded option for that variant).

### Combinatorial explosion

Because all combinations of all variants are generated and compiled, the following scale exponentially:
* Size of the VariantShader resource.
* Time to generate all shader permutations.
* Time to load the VariantShader resource.

The output of 2 variants with 2 options each is 4 generated shaders with a small footprint. Doubling the amoutn of variants leads to generating 16 shaders, and doubling again (to 8 variants) leads to generating 256 shaders.

When declaring variants, keep this in mind:
* Mutually exclusive options should reside in the same variant to avoid generating permutations that shouldn't be representable.
* You can use `VariantShader`'s `exclude_options` parameter to limit the amount of permutations.

When `VariantShader` detects that it would have to generate 1024 or more shaders, a confirmation dialog will appear in the editor with the exact number of permutations.

# AI Disclosure

AI was not used to generate any of the code in this addon. Claude was used as a search/debugging tool during development.