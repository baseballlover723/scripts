package scripts;

public class AmPmToMilitary {

	public static void main(String[] args) {
		String time = "12:05:45AM";
        String[] strs = time.split(":");
        int h = Integer.parseInt(strs[0]);
        int m = Integer.parseInt(strs[1]);
        int s = Integer.parseInt(strs[2].substring(0, 2));
        boolean pm = strs[2].substring(2,4).equals("PM");
        if (h == 12) {
        	h = 0;
        }
        if (pm) {
            h += 12;
        }
        System.out.print(String.format("%02d", h));
        System.out.print(":");
        System.out.print(String.format("%02d", m));
        System.out.print(":");
        System.out.print(String.format("%02d", s));
	}

}
