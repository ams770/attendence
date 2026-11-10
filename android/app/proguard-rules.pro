# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Play Store Split / Deferred Components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# ONNX Runtime
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# Google ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
