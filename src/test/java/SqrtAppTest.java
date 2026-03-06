import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import static org.junit.jupiter.api.Assertions.*;

class SqrtAppTest {

    // ── Happy-path tests ───────────────────────────────────────────

    @Test
    @DisplayName("sqrt of 4 should be 2")
    void testSqrtOfFour() {
        assertEquals(2.0, SqrtApp.sqrt(4.0), 1e-9);
    }

    @Test
    @DisplayName("sqrt of 9 should be 3")
    void testSqrtOfNine() {
        assertEquals(3.0, SqrtApp.sqrt(9.0), 1e-9);
    }

    @Test
    @DisplayName("sqrt of 16 should be 4")
    void testSqrtOfSixteen() {
        assertEquals(4.0, SqrtApp.sqrt(16.0), 1e-9);
    }

    @Test
    @DisplayName("sqrt of 25 should be 5")
    void testSqrtOfTwentyFive() {
        assertEquals(5.0, SqrtApp.sqrt(25.0), 1e-9);
    }

    @Test
    @DisplayName("sqrt of 2 should be ~1.4142")
    void testSqrtOfTwo() {
        assertEquals(1.41421356, SqrtApp.sqrt(2.0), 1e-6);
    }

    // ── Edge-case tests ────────────────────────────────────────────

    @Test
    @DisplayName("sqrt of 0 should be 0")
    void testSqrtOfZero() {
        assertEquals(0.0, SqrtApp.sqrt(0.0), 1e-9);
    }

    @Test
    @DisplayName("sqrt of 1 should be 1")
    void testSqrtOfOne() {
        assertEquals(1.0, SqrtApp.sqrt(1.0), 1e-9);
    }

    @Test
    @DisplayName("sqrt of a large number")
    void testSqrtOfLargeNumber() {
        assertEquals(1000.0, SqrtApp.sqrt(1_000_000.0), 1e-6);
    }

    // ── Error-case tests ───────────────────────────────────────────

    @Test
    @DisplayName("sqrt of negative number throws IllegalArgumentException")
    void testSqrtOfNegativeThrows() {
        assertThrows(IllegalArgumentException.class, () -> SqrtApp.sqrt(-1.0));
    }

    @Test
    @DisplayName("exception message mentions the bad value")
    void testSqrtNegativeExceptionMessage() {
        IllegalArgumentException ex = assertThrows(
                IllegalArgumentException.class, () -> SqrtApp.sqrt(-5.0));
        assertTrue(ex.getMessage().contains("-5.0"));
    }
}
