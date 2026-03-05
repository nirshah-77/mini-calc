FROM openjdk:17

WORKDIR /app

COPY calc.java .

RUN javac calc.java

CMD ["sleep", "infinity"]