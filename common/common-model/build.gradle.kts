plugins {
    `java-library`
}

group = "com.natsu"
version = "1.0-SNAPSHOT"

dependencies {
    // JSON processing for DTOs (versions managed by BOM)
    api("com.fasterxml.jackson.core:jackson-core")
    api("com.fasterxml.jackson.core:jackson-databind")
    api("com.fasterxml.jackson.core:jackson-annotations")
    api("com.fasterxml.jackson.datatype:jackson-datatype-jsr310")
    
    // Validation annotations for DTOs
    api("jakarta.validation:jakarta.validation-api")
    
    // Lombok for reducing boilerplate in DTOs
    compileOnly("org.projectlombok:lombok")
    annotationProcessor("org.projectlombok:lombok")
    
    testImplementation(platform("org.junit:junit-bom:5.10.0"))
    testImplementation("org.junit.jupiter:junit-jupiter")
}

tasks.test {
    useJUnitPlatform()
}
