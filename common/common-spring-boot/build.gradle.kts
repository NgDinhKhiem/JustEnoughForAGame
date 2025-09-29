plugins {
    `java-library`
}

group = "com.natsu.jefag"
version = "1.0-SNAPSHOT"

dependencies {
    // Import specific common modules instead of the parent to avoid circular dependency
    api(project(":common:common-model"))
    api(project(":common:common-utils"))
    // Note: Don't include common-security and common-messaging here to avoid circular deps
    // Services should include them directly if needed
    
    // Spring Boot Core Dependencies (versions managed by BOM)
    api("org.springframework.boot:spring-boot-starter")
    api("org.springframework.boot:spring-boot-starter-web")
    api("org.springframework.boot:spring-boot-starter-actuator")
    api("org.springframework.boot:spring-boot-starter-validation")
    api("org.springframework.boot:spring-boot-starter-security")
    
    // Common Spring Boot Features
    api("org.springframework.boot:spring-boot-starter-data-redis")
    api("org.springframework.kafka:spring-kafka")
    
    // JSON processing
    api("com.fasterxml.jackson.core:jackson-databind")
    api("com.fasterxml.jackson.datatype:jackson-datatype-jsr310")
    
    // Monitoring
    api("io.micrometer:micrometer-registry-cloudwatch")
    
    // AWS Lambda support (optional)
    api("com.amazonaws:aws-lambda-java-core")
    api("com.amazonaws:aws-lambda-java-events")
    api("org.springframework.cloud:spring-cloud-function-adapter-aws")
    
    // AWS SDK (versions managed by BOM)
    api("software.amazon.awssdk:dynamodb")
    api("software.amazon.awssdk:dynamodb-enhanced")
    
    // Lombok - Code generation
    api("org.projectlombok:lombok")
    annotationProcessor("org.projectlombok:lombok")
    
    // Dependency Injection Annotations
    api("jakarta.inject:jakarta.inject-api")
    api("jakarta.annotation:jakarta.annotation-api")
    
    // Configuration Properties
    api("org.springframework.boot:spring-boot-configuration-processor")
    annotationProcessor("org.springframework.boot:spring-boot-configuration-processor")
    
    // Validation
    api("jakarta.validation:jakarta.validation-api")
    api("org.hibernate.validator:hibernate-validator")
    
    // Utilities
    api("org.apache.commons:commons-lang3")
    api("org.apache.commons:commons-collections4")
    api("com.google.guava:guava")
    
    // Async and Reactive Support
    api("org.springframework:spring-context-support")
    api("org.springframework.boot:spring-boot-starter-webflux")
    
    // Caching Support
    api("org.springframework.boot:spring-boot-starter-cache")
    api("com.github.ben-manes.caffeine:caffeine")
    
    // Metrics and Health Checks
    api("io.micrometer:micrometer-core")
    api("io.micrometer:micrometer-registry-prometheus")
    
    // Logging (SLF4J is included with Spring Boot)
    api("net.logstash.logback:logstash-logback-encoder")
    
    // Date/Time utilities
    api("org.threeten:threeten-extra")
    
    // Testing
    api("org.springframework.boot:spring-boot-starter-test")
    api("org.springframework.security:spring-security-test")
    api("org.testcontainers:junit-jupiter")
    api("org.testcontainers:localstack")
    api("org.mockito:mockito-core")
    api("org.mockito:mockito-junit-jupiter")
    api("org.assertj:assertj-core")
}

tasks.test {
    useJUnitPlatform()
}
