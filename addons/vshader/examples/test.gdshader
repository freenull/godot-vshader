// @variant DEBUG OFF ON
// @variant FOOBAR OFF ON

shader_type spatial;

#ifdef FOOBAR_ON
uniform float a;
#endif

#ifdef DEBUG_ON
uniform float b;
#endif

void vertex() {
#ifdef FOOBAR_ON

#ifdef DEBUG_ON
    VERTEX.y += 1.0 * a;
#endif

#ifndef DEBUG_ON
    VERTEX.y -= 1.0 * a;
#endif

#endif
}
