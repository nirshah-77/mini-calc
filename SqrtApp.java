public class SqrtApp {
    public static void main(String[] args) {
        double[] testValues = {4.0, 9.0, 16.0, 25.0, 2.0};

        System.out.println("=== Square Root Calculator ===");
        for (double num : testValues) {
            double result = Math.sqrt(num);
            System.out.printf("sqrt(%.1f) = %.4f%n", num, result);
        }
        System.out.println("==============================");
    }
}
