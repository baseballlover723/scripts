package scripts;

public class LeastSig {

	public LeastSig() {
		// TODO Auto-generated constructor stub
	}

	public static void main(String[] args) {
		for (int i = -10; i < 10; i++) {
			System.out.println(getLeastSignificant2(i) + " " + getLeastSignificant2Mod(i));
		}
	}

	public static int getLeastSignificant2(int num) {
		return num & 3;
	}

	public static int getLeastSignificant2Mod(int num) {
		int modResult = num % 4;
		return modResult < 0 ? modResult + 4 : modResult;
	}
}
