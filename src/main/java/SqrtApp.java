public class SqrtApp {

    /**
     * Returns the square root of the given number.
     * Throws IllegalArgumentException for negative input.
     */
    public static double sqrt(double number) {
        if (number < 0) {
            throw new IllegalArgumentException("Cannot compute square root of a negative number: " + number);
        }
        return Math.sqrt(number);
    }

    public static void main(String[] args) {
        double[] testValues = {4.0, 9.0, 16.0, 25.0, 2.0};

        for (double num : testValues) {
            System.out.printf("sqrt(%.1f) = %.4f%n", num, sqrt(num));
        }
    }
}
