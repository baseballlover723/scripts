package scripts;

import java.util.Scanner;
import java.util.Stack;

public class EqualStacks {

	public static void main(String[] args) {
		// TODO Auto-generated method stub
		Scanner in = new Scanner("5 3 4\n3 2 1 1 1\n4 3 2\n1 1 4 1");
		int n1 = in.nextInt();
		int n2 = in.nextInt();
		int n3 = in.nextInt();
		int h1[] = new int[n1];
		for (int h1_i = 0; h1_i < n1; h1_i++) {
			h1[h1_i] = in.nextInt();
		}
		int h2[] = new int[n2];
		for (int h2_i = 0; h2_i < n2; h2_i++) {
			h2[h2_i] = in.nextInt();
		}
		int h3[] = new int[n3];
		for (int h3_i = 0; h3_i < n3; h3_i++) {
			h3[h3_i] = in.nextInt();
		}

		Stack<Integer> stack1 = new Stack<Integer>();
		Stack<Integer> stack2 = new Stack<Integer>();
		Stack<Integer> stack3 = new Stack<Integer>();
		for (int i=n1-1;i>=0;i--) {
			stack1.push(h1[i]);
		}
		
		for (int i=n2-1;i>=0;i--) {
			stack2.push(h2[i]);
		}
		
		for (int i=n3-1;i>=0;i--) {
			stack3.push(h3[i]);
		}
		
		int height1 = sum(h1);
		int height2 = sum(h2);
		int height3 = sum(h3);

		int height = Math.min(Math.min(height1, height2), height3);
		int diff1 = height1 - height;
		int diff2 = height2 - height;
		int diff3 = height3 - height;
//		System.out.println(diff1);
//		System.out.println(diff2);
//		System.out.println(diff3);
		
		while (diff1 != diff2 || diff2 != diff3 || diff1 != diff3) {
			int maxDiff = Math.max(Math.max(diff1, diff2), diff3);
			if (maxDiff == diff1) {
				diff1 -= stack1.pop();
			} else if (maxDiff == diff2) {
				diff2 -= stack2.pop();
			} else {
				diff3 -= stack3.pop();
			}
		}
//		System.out.println();
//		System.out.println(diff1);
//		System.out.println(diff2);
//		System.out.println(diff3);
		System.out.println(height + diff1);

	}

	public static int sum(int[] arr) {
		int sum = 0;
		for (int i : arr) {
			sum += i;
		}
		return sum;
	}

}
