# Keep TensorFlow Lite GPU Delegate classes and inner class members
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**

# Keep inner class members (Options) in the GPU delegate
-keepclassmembers class org.tensorflow.lite.gpu.GpuDelegate$Options { *; }