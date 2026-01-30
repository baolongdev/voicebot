#include "include/flutter_sound/flutter_sound_plugin.h"
#include "include/taudio/taudio_plugin.h"

void flutter_sound_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  taudio_plugin_register_with_registrar(registrar);
}
