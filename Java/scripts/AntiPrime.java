package scripts;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.Arrays;

public class AntiPrime {

	public static void main(String[] args) throws NumberFormatException, IOException {
		int[] antiPrimes = { 1, 2, 4, 6, 12, 24, 36, 48, 60, 120, 180, 240, 360, 720, 840, 1260, 1680, 2520, 5040, 7560,
				10080, 15120, 20160, 25200, 27720, 45360, 50400, 55440, 83160, 110880, 166320, 221760, 277200, 332640,
				498960, 554400, 665280, 720720, 1081080, 1441440, 2162160, 2882880, 3603600, 4324320, 6486480, 7207200,
				8648640, 10810800, 14414400, 17297280, 21621600 };
		BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
		int n = Integer.parseInt(in.readLine());
		StringBuilder sb = new StringBuilder();
		for (int i = 0; i < n; i++) {
			int q = Integer.parseInt(in.readLine());
			sb.append(findSmallestAntiPrime(antiPrimes, q));
			sb.append('\n');
		}
		System.out.println(sb.toString());
	}

	private static int findSmallestAntiPrime(int[] antiPrimes, int q) {
		int index = Arrays.binarySearch(antiPrimes, q);
		if (index < 0) {
			index = Math.abs(index + 1);
		}
		return antiPrimes[index];
	}

}
