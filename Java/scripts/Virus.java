package scripts;

import java.util.Scanner;

public class Virus {

	public static void main(String[] args) {
		Scanner scanner = new Scanner("2 4 456");
		long a = scanner.nextLong();
		long b = scanner.nextLong();
		long t = scanner.nextLong();

		if (t < 0) {
			throw new RuntimeException();
		}
		System.out.println(pow((a + b) / 2, t, 1_000_000_007));
	}

	// ( (a mod p) (b mod p) ) mod p = (ab) mod p
	public static long pow(long a, long e, long m) {
		long numb = 1; // Initialize result

		a = a % m;
		while (e > 0) {
			if (e % 2 == 1) {
				numb = (numb * a) % m;
			}
			e /= 2;
			a = (a * a) % m;
		}
		return numb;
	}

}
