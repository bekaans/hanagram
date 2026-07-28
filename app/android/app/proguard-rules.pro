# Hanagram — ProGuard kuralları (release build için)
#
# Flutter varsayılan olarak yeterli ProGuard kurallarını içerir.
# Buraya özel kurallar ekleyebilirsiniz.

# Supabase
-keep class io.github.jan-tennert.supabase.** { *; }

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

#general
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
