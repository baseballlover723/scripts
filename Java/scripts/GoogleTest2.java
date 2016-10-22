package scripts;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Stack;

public class GoogleTest2 {
	// <div id="brinza-task-description">
	// <p>You are given a listing of directories and files in a file system.
	// Each directory and file has a <i>name</i>, which is a non-empty string
	// consisting of alphanumerical characters. Additionally, the name of each
	// file contains a single dot character; the part of the name starting with
	// the dot is called the <i>extension</i>. Directory names do not contain
	// any dots. All the names are case-sensitive.</p>
	// <p>Each entry is listed on a separate line. Every directory is followed
	// by the listing of its contents indented by one space character. The
	// contents of the root directory are not indented.</p>
	// <p>Here is a sample listing:</p>
	// <tt style="white-space:pre-wrap">
	// dir1
	// *dir11
	// *dir12
	// **picture.jpeg
	// **dir121
	// **file1.txt
	// dir2
	// *file2.gif</tt>
	// <p>We have three files (<tt
	// style="white-space:pre-wrap">picture.jpeg</tt>, <tt
	// style="white-space:pre-wrap">file1.txt</tt> and <tt
	// style="white-space:pre-wrap">file2.gif</tt>) and six directories (<tt
	// style="white-space:pre-wrap">dir1</tt>, <tt
	// style="white-space:pre-wrap">dir11</tt>, <tt
	// style="white-space:pre-wrap">dir12</tt>, <tt
	// style="white-space:pre-wrap">dir121</tt>, <tt
	// style="white-space:pre-wrap">dir2</tt> and the root directory). Directory
	// <tt style="white-space:pre-wrap">dir12</tt> contains two files (<tt
	// style="white-space:pre-wrap">picture.jpeg</tt> and <tt
	// style="white-space:pre-wrap">file1.txt</tt>) and an empty directory (<tt
	// style="white-space:pre-wrap">dir121</tt>). The root directory contains
	// two directories (<tt style="white-space:pre-wrap">dir1</tt> and <tt
	// style="white-space:pre-wrap">dir2</tt>).</p>
	// <p>The <i>absolute path</i> of a file is a string containing the names of
	// directories which have to be traversed (from the root directory) to reach
	// the file, separated by slash characters. For example, the absolute path
	// to the file <tt style="white-space:pre-wrap">file1.txt</tt> is "<tt
	// style="white-space:pre-wrap">/dir1/dir12/file1.txt</tt>". Note that there
	// is no "drive letter", such as "<tt style="white-space:pre-wrap">C:</tt>",
	// and each absolute path starts with a slash.</p>
	// <p>We are interested in <i>image files</i> only; that is, files with
	// extensions <tt style="white-space:pre-wrap">.jpeg</tt>, <tt
	// style="white-space:pre-wrap">.png</tt> or <tt
	// style="white-space:pre-wrap">.gif</tt> (and only these extensions). We
	// are looking for the total length of all the absolute paths leading to the
	// image files. For example, in the file system described above there are
	// two image files: "<tt
	// style="white-space:pre-wrap">/dir1/dir12/picture.jpeg</tt>" and "<tt
	// style="white-space:pre-wrap">/dir2/file2.gif</tt>". The total length of
	// the absolute paths to these files is 24 + 15 = 39.</p>
	// <p>Write a function:</p>
	// <blockquote><p class="lang-java" style="font-family: monospace;
	// font-size: 9pt; display: block; white-space: pre-wrap"><tt>class Solution
	// { public int solution(String S); }</tt></p></blockquote>
	// <p>that, given a string S consisting of N characters which contains the
	// listing of a file system, returns the total of lengths (in characters)
	// modulo 1,000,000,007 of all the absolute paths to the image files.</p>
	// <p>For example, given the sample listing shown above, the function should
	// return 39, as explained above. If there are no image files, the function
	// should return 0.</p>
	// <p>Assume that:</p>
	// <blockquote><ul style="margin: 10px;padding: 0px;"><li>N is an integer
	// within the range [<span class="number">1</span>..<span
	// class="number">3,000,000</span>];</li>
	// <li>string S consists only of alphanumerical characters (<tt
	// style="white-space:pre-wrap">a</tt>-<tt
	// style="white-space:pre-wrap">z</tt> and/or <tt
	// style="white-space:pre-wrap">A</tt>-<tt
	// style="white-space:pre-wrap">Z</tt> and/or <tt
	// style="white-space:pre-wrap">0</tt>-<tt
	// style="white-space:pre-wrap">9</tt>), spaces, dots (<tt
	// style="white-space:pre-wrap">.</tt>) and end-of-line characters;</li>
	// <li>string S is a correct listing of a file system contents.</li>
	// </ul>
	// </blockquote><p>Complexity:</p>
	// <blockquote><ul style="margin: 10px;padding: 0px;"><li>expected
	// worst-case time complexity is O(N);</li>
	// <li>expected worst-case space complexity is O(N) (not counting the
	// storage required for input arguments).</li>
	// </ul>
	// </blockquote></div>
	public static void main(String[] args) {
		// TODO Auto-generated method stub
		String s = "dir1\n dir11\n dir12\n  picture.jpeg\n  dir121\n  file1.txt\ndir2\n file2.gif";
		Directory root = new Directory("", "", -1);
		Stack<Directory> currentDirectory = new Stack<Directory>();
		currentDirectory.push(root);
		for (String line : s.split("\n")) {
			int indent = getIndentLevel(line);
			while (indent <= currentDirectory.peek().indentLevel) {
				// System.out.println(currentDirectory.peek().name + ": " +
				// currentDirectory.peek().indentLevel + ", " +
				// (currentDirectory.peek().indentLevel + 1 - indent));
				// for (int i = 0; i < currentDirectory.peek().indentLevel + 1 -
				// indent; i++) {
				// System.out.println(line);
				currentDirectory.pop();
				// }
			}
			if (!line.contains(".")) {
				Directory dir = new Directory(line.substring(indent),
						currentDirectory.peek().pathToParent + currentDirectory.peek().name + "/",
						currentDirectory.peek().indentLevel + 1);
				currentDirectory.peek().contents.add(dir);
				currentDirectory.push(dir);
			} else {
				currentDirectory.peek().contents.add(new File(line.substring(indent),
						currentDirectory.peek().pathToParent + currentDirectory.peek().name + "/",
						currentDirectory.peek().indentLevel + 1));
			}
		}

		System.out.println(root);
		System.out.println();
		System.out.println("******");
		System.out.println();
		System.out.println(root.findLengthOfImages());
		System.out.println(39);
	}

	public static int getIndentLevel(String str) {
		for (int i = 0; i < str.length(); i++) {
			if (str.charAt(i) != ' ') {
				return i;
			}
		}
		return -1;
	}
}

abstract class FileObject {
	public String name;
	public String pathToParent;
	public int indentLevel;

	public FileObject(String name, String pathToParent, int indentLevel) {
		this.name = name;
		this.pathToParent = pathToParent;
		this.indentLevel = indentLevel;
		// if (indentLevel == 0) {
		//
		// } else {
		//
		// }
	}

	public abstract int findLengthOfImages();
}

class Directory extends FileObject {
	public ArrayList<FileObject> contents;

	public Directory(String name, String pathToParent, int indentLevel) {
		super(name, pathToParent, indentLevel);
		this.contents = new ArrayList<FileObject>();
	}

	public String toString() {
		String spaces = "";
		for (int i = 0; i < indentLevel; i++) {
			spaces += " ";
		}
		String str = spaces + this.name;
		for (FileObject obj : this.contents) {
			str += "\n" + obj.toString();
		}
		return str;
	}

	@Override
	public int findLengthOfImages() {
		int total = 0;
		for (FileObject obj : this.contents) {
			total += obj.findLengthOfImages();
		}
		return total;
	}
}

class File extends FileObject {
	private String extension;

	public File(String name, String pathToParent, int indentLevel) {
		super(name.split("\\.")[0], pathToParent, indentLevel);
		this.extension = name.split("\\.")[1];
		this.findLengthOfImages();

	}

	public String toString() {
		String spaces = "";
		for (int i = 0; i < indentLevel; i++) {
			spaces += " ";
		}
		return spaces + this.name + "." + this.extension;
	}

	@Override
	public int findLengthOfImages() {
		if (this.extension.equals("jpeg") || this.extension.equals("png") || this.extension.equals("gif")) {
			return this.pathToParent.length() + this.name.length() + this.extension.length() + 1;
		} else {
			return 0;
		}
	}
}
