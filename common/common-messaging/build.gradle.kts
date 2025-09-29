plugins {
    `java-library`
}

group = "com.natsu.jefag"
version = "1.0-SNAPSHOT"

dependencies {
    api(project(":common:common-model"))
    api(project(":common:common-utils"))
    
    // Kafka dependencies (versions managed by BOM)
    api("org.apache.kafka:kafka-clients")
    api("org.springframework.kafka:spring-kafka")
    
    // Redis dependencies (versions managed by BOM)
    api("org.springframework.data:spring-data-redis")
    api("redis.clients:jedis")
    api("io.lettuce:lettuce-core")
    
    // Message serialization
    api("com.fasterxml.jackson.core:jackson-databind")
    api("org.apache.avro:avro")
    
    // Spring Context for dependency injection
    api("org.springframework:spring-context")
    
    // Logging
    api("org.slf4j:slf4j-api")
    
    // Lombok
    compileOnly("org.projectlombok:lombok")
    annotationProcessor("org.projectlombok:lombok")
    
    testImplementation(platform("org.junit:junit-bom:5.10.0"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testImplementation("org.mockito:mockito-core")
    testImplementation("org.springframework.kafka:spring-kafka-test")
    testImplementation("org.testcontainers:kafka")
    testImplementation("org.testcontainers:junit-jupiter")
}

tasks.test {
    useJUnitPlatform()
}
