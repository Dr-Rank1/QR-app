buildscript {
    repositories {
        google()
        mavenCentral()
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force consistent versions of Google Play services libraries
configurations.all {
    resolutionStrategy {
        force("com.google.android.gms:play-services-measurement-api:22.0.2")
        force("com.google.android.gms:play-services-measurement-sdk:22.0.2")
    }
}

// Fix for plugins without namespace
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            if (android != null) {
                val androidExt = android as com.android.build.gradle.BaseExtension
                if (androidExt.namespace.isNullOrEmpty()) {
                    androidExt.namespace = project.group.toString()
                }
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
