import java.util.Scanner;

public class calc {

    public static double sqrt(double n) {
        if (n < 0) throw new IllegalArgumentException("Cannot sqrt negative number: " + n);
        return Math.sqrt(n);
    }

    public static long factorial(int n) {
        if (n < 0) throw new IllegalArgumentException("Cannot factorial negative number: " + n);
        long result = 1;
        for (int i = 2; i <= n; i++) result *= i;
        return result;
    }

    public static double ln(double n) {
        if (n <= 0) throw new IllegalArgumentException("ln requires a positive number, got: " + n);
        return Math.log(n);
    }

    public static double power(double base, double exp) {
        return Math.pow(base, exp);
    }

    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);

        while (true) {
            System.out.println("\n=== Mini Calculator ===");
            System.out.println("1. Square Root");
            System.out.println("2. Factorial");
            System.out.println("3. Natural Logarithm (ln)");
            System.out.println("4. Power (a^b)");
            System.out.println("5. Exit");
            System.out.print("Choose an option: ");

            int choice = sc.nextInt();

            if (choice == 5) {
                System.out.println("Goodbye!");
                break;
            }

            try {
                switch (choice) {
                    case 1:
                        System.out.print("Enter number: ");
                        System.out.printf("Result: %.6f%n", sqrt(sc.nextDouble()));
                        break;
                    case 2:
                        System.out.print("Enter non-negative integer: ");
                        System.out.printf("Result: %d%n", factorial(sc.nextInt()));
                        break;
                    case 3:
                        System.out.print("Enter number (> 0): ");
                        System.out.printf("Result: %.6f%n", ln(sc.nextDouble()));
                        break;
                    case 4:
                        System.out.print("Enter base: ");
                        double base = sc.nextDouble();
                        System.out.print("Enter exponent: ");
                        System.out.printf("Result: %.6f%n", power(base, sc.nextDouble()));
                        break;
                    default:
                        System.out.println("Invalid option. Please choose 1-5.");
                }
            } catch (IllegalArgumentException e) {
                System.out.println("Error: " + e.getMessage());
            }
        }

        sc.close();
    }
}
