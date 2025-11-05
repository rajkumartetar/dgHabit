allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Ensure all Android library modules (plugins) compile against SDK 35
subprojects {
    // Fallback: force compileSdk for any Android library module via reflection (AGP 7/8 compatible)
    pluginManager.withPlugin("com.android.library") {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            // Try AGP 8+ setter
            val setCompileSdk = runCatching {
                androidExt.javaClass.getMethod("setCompileSdk", Int::class.javaPrimitiveType)
            }.getOrNull()
            if (setCompileSdk != null) {
                runCatching { setCompileSdk.invoke(androidExt, 35) }
            } else {
                // Fallback to older AGP setter
                val setCompileSdkVersion = runCatching {
                    androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                }.getOrNull()
                if (setCompileSdkVersion != null) {
                    runCatching { setCompileSdkVersion.invoke(androidExt, 35) }
                }
            }

            // Also pin buildToolsVersion where available to ensure aapt2 compatibility
            val setBuildTools = runCatching {
                androidExt.javaClass.getMethod("setBuildToolsVersion", String::class.java)
            }.getOrNull()
            if (setBuildTools != null) {
                runCatching { setBuildTools.invoke(androidExt, "35.0.0") }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
