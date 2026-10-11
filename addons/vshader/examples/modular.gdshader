shader_type spatial;

//@variant FILE inc "modular/displace_none.gdshaderinc" { "modular/displace_down.gdshaderinc", "modular/displace_up.gdshaderinc" }

#include "modular/displace_none.gdshaderinc"

void vertex() {
    VERTEX = displace_vertex(VERTEX);
}
