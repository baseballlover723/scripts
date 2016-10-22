package scripts;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Stack;

public class Test {
	public static String closestColor(String str) {
		String red = "111111110000000000000000";
		String green = "000000001111111100000000";
		String blue = "000000000000000011111111";
		String white = "111111111111111111111111";
		String black = "000000000000000000000000";
		ArrayList<Integer> distances = new ArrayList<Integer>();

		double redD = distance(str, red);
		double greenD = distance(str, green);
		double blueD = distance(str, blue);
		double whiteD = distance(str, white);
		double blackD = distance(str, black);

		double minD = Math.min(Math.min(Math.min(Math.min(redD, greenD), blueD), whiteD), blackD);
		String closestColor = "";
		if (minD == redD) {
			closestColor = "red";
		}
		if (minD == blueD) {
			if (closestColor.equals("")) {
				closestColor = "blue";
			} else {
				closestColor = "Ambiguous";
			}
		}
		if (minD == greenD) {
			if (closestColor.equals("")) {
				closestColor = "green";
			} else {
				closestColor = "Ambiguous";
			}
		}
		if (minD == whiteD) {
			if (closestColor.equals("")) {
				closestColor = "white";
			} else {
				closestColor = "Ambiguous";
			}
		}
		if (minD == blackD) {
			if (closestColor.equals("")) {
				closestColor = "black";
			} else {
				closestColor = "Ambiguous";
			}
		}

		return closestColor;

	}

	public static double distance(String c1, String c2) {
		int r1 = Integer.parseInt(c1.substring(0, 8), 2);
		int g1 = Integer.parseInt(c1.substring(8, 16), 2);
		int b1 = Integer.parseInt(c1.substring(16, 24), 2);
		int r2 = Integer.parseInt(c2.substring(0, 8), 2);
		int g2 = Integer.parseInt(c2.substring(8, 16), 2);
		int b2 = Integer.parseInt(c2.substring(16, 24), 2);

		int dr = r1 - r2;
		int dg = g1 - g2;
		int db = b1 - b2;

		return Math.sqrt((dr * dr + dg * dg + db * db));

	}

	public static void main(String[] args) {
		System.out.println(closestColor("111111100000000000000000")); //red
		System.out.println(closestColor("000010010000000011111110")); //blue
		System.out.println(closestColor("111111111111111100000000")); //ambiguous
		System.out.println(closestColor("111110111111011111111111")); //white
		System.out.println(closestColor("000000000000100010000000")); //black
		System.out.println(closestColor("000100001111011110000000")); // green

	}
}
