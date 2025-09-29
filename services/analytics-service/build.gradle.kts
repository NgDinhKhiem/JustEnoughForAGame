plugins {
    id("org.springframework.boot") version "3.2.0"
    id("io.spring.dependency-management") version "1.1.4"
    java
}

group = "com.natsu.jefag"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

dependencies {
    // Use common Spring Boot template with all standard dependencies
    implementation(project(":common:common-spring-boot"))
    implementation(project(":common:common-messaging"))
    
    // Analytics-specific dependencies (versions managed by BOM)
    implementation("org.apache.kafka:kafka-streams")
    implementation("com.clickhouse:clickhouse-jdbc")
    implementation("com.clickhouse:clickhouse-http-client")
    implementation("software.amazon.awssdk:s3")
    implementation("org.springframework.boot:spring-boot-starter-batch")
    implementation("org.apache.commons:commons-math3")
    implementation("org.apache.commons:commons-csv")
    implementation("com.opencsv:opencsv")
    implementation("com.h2database:h2")
    
    // Testing
    testImplementation("org.springframework.kafka:spring-kafka-test")
    testImplementation("org.springframework.batch:spring-batch-test")
    testImplementation("org.testcontainers:kafka")
}

tasks.test {
    useJUnitPlatform()
}

tasks.named<org.springframework.boot.gradle.tasks.bundling.BootJar>("bootJar") {
    archiveFileName.set("${project.name}.jar")
}


