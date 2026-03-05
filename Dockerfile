FROM openjdk:17-slim

WORKDIR /app

# Copy and compile the Java source
COPY SqrtApp.java .
RUN javac SqrtApp.java

# Run the application
CMD ["java", "SqrtApp"]