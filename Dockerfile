FROM eclipse-temurin:17-jdk-alpine

WORKDIR /app

# Copy and compile both Java sources
COPY SqrtApp.java calc.java ./
RUN javac SqrtApp.java calc.java

# Keep container alive — connect interactively with:
#   docker exec -it sqrt-app java calc
CMD ["tail", "-f", "/dev/null"]
