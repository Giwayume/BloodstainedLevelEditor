using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;

public class FileExt {
    public static IEnumerable<string> GetFilesRecursive(string path) {
        Queue<string> queue = new Queue<string>();
        queue.Enqueue(path);
        while (queue.Count > 0) {
            path = queue.Dequeue();
            try {
                foreach (string subDir in Directory.GetDirectories(path)) {
                    queue.Enqueue(subDir);
                }
            }
            catch(Exception ex) {
                Console.Error.WriteLine(ex);
            }
            string[] files = null;
            try {
                files = Directory.GetFiles(path);
            }
            catch (Exception ex) {
                Console.Error.WriteLine(ex);
            }
            if (files != null) {
                for(int i = 0 ; i < files.Length ; i++) {
                    yield return files[i];
                }
            }
        }
    }
}
