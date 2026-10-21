# ============================================================================
# ChargeAlarm Security & ProGuard / R8 Obfuscation Rules
# ============================================================================

# Code Obfuscation & Optimization
-repackageclasses 'com.chargealarm.app.internal'
-allowaccessmodification

# Strip out debug logcat calls to prevent info leakage to attackers
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
}

# Don't warn on missing optional classes in plugins
-dontwarn **
-ignorewarnings

# Flutter Embedding & Method Channels (keep entry points)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Local Notifications
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# Keep App Components (Activities, Services, Receivers)
-keep public class com.chargealarm.app.MainActivity {
    public *;
}

-keep public class com.chargealarm.app.BatteryMonitoringService {
    public *;
}

-keep public class com.chargealarm.app.AlarmActionReceiver {
    public *;
}

# Keep Desugaring classes
-keep class j$.** { *; }

# Prevent tampering with Kotlin metadata
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Prevent reverse engineering of serialization models
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
