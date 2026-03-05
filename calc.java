import java.util.Scanner;

public class calc {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);

        System.out.println("Enter a number:");

        double num = sc.nextDouble();

        double result = Math.sqrt(num);

        System.out.println("Square root: " + result);
    }
}