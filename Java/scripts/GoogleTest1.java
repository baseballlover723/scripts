package scripts;

public class GoogleTest1 {
//	<div id="brinza-task-description">
//	<p>You are given an integer X. You must choose two adjacent digits and replace them with the larger of these two digits.</p>
//	<p>For example, from the integer X = 233614, you can obtain:</p>
//	<blockquote><ul style="margin: 10px;padding: 0px;"><li>33614 (by replacing 23 with 3);</li>
//	<li>23614 (by replacing 33 with 3 or 36 with 6);</li>
//	<li>23364 (by replacing 61 with 6 or 14 with 4).</li>
//	</ul>
//	</blockquote><p>You want to find the smallest number that can be obtained from X by replacing two adjacent digits with the larger of the two. In the above example, the smallest such number is 23364.</p>
//	<p>Write a function:</p>
//	<blockquote><p class="lang-java" style="font-family: monospace; font-size: 9pt; display: block; white-space: pre-wrap"><tt>class Solution { public int solution(int X); }</tt></p></blockquote>
//	<p>that, given a positive integer X, returns the smallest number that can be obtained from X by replacing two adjacent digits with the larger of the two.</p>
//	<p>For example, given X = 233614, the function should return 23364, as explained above.</p>
//	<p>Assume that:</p>
//	<blockquote><ul style="margin: 10px;padding: 0px;"><li>X is an integer within the range [<span class="number">10</span>..<span class="number">1,000,000,000</span>].</li>
//	</ul>
//	</blockquote><p>In your solution, focus on <b><b>correctness</b></b>. The performance of your solution will not be the focus of the assessment.</p>
//	</div>
	public static void main(String[] args) {
		// TODO Auto-generated method stub
		System.out.println(findMinNaive(233614));
		System.out.println("23364");
		System.out.println();
		System.out.println(findMinNaive(532624));
		//                              52624

	}

	public static int findMinNaive(int x) {
		StringBuilder sb = new StringBuilder(String.valueOf(x));
		int currentMin = Integer.MAX_VALUE;
		for (int i = 1; i < sb.length(); i++) {
			String maxAdjecant = Character.toString((char) Math.max(sb.charAt(i-1), sb.charAt(i)));
			StringBuilder newStr = new StringBuilder(sb).replace(i-1, i+1, maxAdjecant);
			int value = Integer.parseInt(newStr.toString());
			if (value < currentMin) {
				currentMin = value;
			}
		}
		return currentMin;
	}
	
	public static int findMin(int x) {
		String str = String.valueOf(x);
		int currentMinMax = 100000000;
		int currentMinMaxIndex = -1;
		for (int i=1; i<str.length(); i++) {
		}
		return 0;
		
	}

}
