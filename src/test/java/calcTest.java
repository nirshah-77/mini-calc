import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import static org.junit.jupiter.api.Assertions.*;

class CalcTest {

    // ════════════════════════════════════════════════════════════
    //  SQRT TESTS
    // ════════════════════════════════════════════════════════════

    @Test @DisplayName("sqrt(0) = 0")
    void testSqrt0()   { assertEquals(0.0,  calc.sqrt(0),   1e-9); }

    @Test @DisplayName("sqrt(1) = 1")
    void testSqrt1()   { assertEquals(1.0,  calc.sqrt(1),   1e-9); }

    @Test @DisplayName("sqrt(4) = 2")
    void testSqrt4()   { assertEquals(2.0,  calc.sqrt(4),   1e-9); }

    @Test @DisplayName("sqrt(9) = 3")
    void testSqrt9()   { assertEquals(3.0,  calc.sqrt(9),   1e-9); }

    @Test @DisplayName("sqrt(16) = 4")
    void testSqrt16()  { assertEquals(4.0,  calc.sqrt(16),  1e-9); }

    @Test @DisplayName("sqrt(25) = 5")
    void testSqrt25()  { assertEquals(5.0,  calc.sqrt(25),  1e-9); }

    @Test @DisplayName("sqrt(2) ≈ 1.41421")
    void testSqrt2()   { assertEquals(1.41421356, calc.sqrt(2), 1e-5); }

    @Test @DisplayName("sqrt(negative) throws")
    void testSqrtNeg() { assertThrows(IllegalArgumentException.class, () -> calc.sqrt(-1)); }

    // ════════════════════════════════════════════════════════════
    //  FACTORIAL TESTS
    // ════════════════════════════════════════════════════════════

    @Test @DisplayName("0! = 1")
    void testFact0()  { assertEquals(1L,       calc.factorial(0)); }

    @Test @DisplayName("1! = 1")
    void testFact1()  { assertEquals(1L,       calc.factorial(1)); }

    @Test @DisplayName("2! = 2")
    void testFact2()  { assertEquals(2L,       calc.factorial(2)); }

    @Test @DisplayName("3! = 6")
    void testFact3()  { assertEquals(6L,       calc.factorial(3)); }

    @Test @DisplayName("5! = 120")
    void testFact5()  { assertEquals(120L,     calc.factorial(5)); }

    @Test @DisplayName("7! = 5040")
    void testFact7()  { assertEquals(5040L,    calc.factorial(7)); }

    @Test @DisplayName("10! = 3628800")
    void testFact10() { assertEquals(3628800L, calc.factorial(10)); }

    @Test @DisplayName("factorial(negative) throws")
    void testFactNeg() { assertThrows(IllegalArgumentException.class, () -> calc.factorial(-1)); }

    // ════════════════════════════════════════════════════════════
    //  NATURAL LOG (ln) TESTS
    // ════════════════════════════════════════════════════════════

    @Test @DisplayName("ln(1) = 0")
    void testLn1()  { assertEquals(0.0, calc.ln(1),      1e-9); }

    @Test @DisplayName("ln(e) = 1")
    void testLnE()  { assertEquals(1.0, calc.ln(Math.E), 1e-9); }

    @Test @DisplayName("ln(e^2) = 2")
    void testLnE2() { assertEquals(2.0, calc.ln(Math.E * Math.E), 1e-9); }

    @Test @DisplayName("ln(10) ≈ 2.30259")
    void testLn10() { assertEquals(2.302585, calc.ln(10), 1e-5); }

    @Test @DisplayName("ln(0) throws")
    void testLn0()  { assertThrows(IllegalArgumentException.class, () -> calc.ln(0)); }

    @Test @DisplayName("ln(negative) throws")
    void testLnNeg(){ assertThrows(IllegalArgumentException.class, () -> calc.ln(-3)); }

    // ════════════════════════════════════════════════════════════
    //  POWER TESTS
    // ════════════════════════════════════════════════════════════

    @Test @DisplayName("2^0 = 1")
    void testPow2_0()  { assertEquals(1.0,    calc.power(2,  0),  1e-9); }

    @Test @DisplayName("2^1 = 2")
    void testPow2_1()  { assertEquals(2.0,    calc.power(2,  1),  1e-9); }

    @Test @DisplayName("2^8 = 256")
    void testPow2_8()  { assertEquals(256.0,  calc.power(2,  8),  1e-9); }

    @Test @DisplayName("2^10 = 1024")
    void testPow2_10() { assertEquals(1024.0, calc.power(2,  10), 1e-9); }

    @Test @DisplayName("3^3 = 27")
    void testPow3_3()  { assertEquals(27.0,   calc.power(3,  3),  1e-9); }

    @Test @DisplayName("5^3 = 125")
    void testPow5_3()  { assertEquals(125.0,  calc.power(5,  3),  1e-9); }

    @Test @DisplayName("2^-1 = 0.5")
    void testPowNeg()  { assertEquals(0.5,    calc.power(2,  -1), 1e-9); }

    @Test @DisplayName("0^0 = 1 (Java convention)")
    void testPow0_0()  { assertEquals(1.0,    calc.power(0,  0),  1e-9); }
}
