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

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library") ||
            plugins.hasPlugin("com.android.application")) {

            extensions.findByName("android")?.let { ext ->
                try {
                    val namespaceField = ext::class.java.getMethod("getNamespace")
                    val currentNamespace = namespaceField.invoke(ext) as String?

                    if (currentNamespace == null) {
                        val setNamespace = ext::class.java.getMethod(
                            "setNamespace",
                            String::class.java
                        )
                        setNamespace.invoke(ext, project.group.toString())
                    }
                } catch (_: Exception) {
                }
            }
        }
    }
}
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
