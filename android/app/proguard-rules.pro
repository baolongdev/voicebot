# Keep native method signatures used by platform channels.
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep annotation metadata for libraries that inspect runtime annotations.
-keepattributes *Annotation*
