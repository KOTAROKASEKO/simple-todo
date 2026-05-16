allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Force library modules to API 36 for plugins using newer Android symbols.
fun org.gradle.api.Project.applyLibraryCompileSdk36() {
    if (!plugins.hasPlugin("com.android.library")) {
        return
    }
    val androidExt = extensions.findByName("android") ?: return
    val intType = Int::class.javaPrimitiveType!!
    val target = 36
    for (name in listOf("setCompileSdk", "setCompileSdkVersion")) {
        try {
            androidExt.javaClass.getMethod(name, intType).invoke(androidExt, target)
            break
        } catch (_: Exception) {
        }
    }
}

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// evaluationDependsOn(":app") can leave plugins already evaluated; late afterEvaluate then throws.
subprojects {
    if (project.state.executed) {
        project.applyLibraryCompileSdk36()
    } else {
        project.afterEvaluate {
            project.applyLibraryCompileSdk36()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
