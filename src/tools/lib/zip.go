package lib

import (
	"archive/zip"
	"io"
	"io/fs"
	"os"
	"path/filepath"
)

// CountingWriter wraps an io.Writer and counts the number of bytes written.
type CountingWriter struct {
	written int64
	writer  io.Writer
}

// Write writes bytes and counts them.
func (cw *CountingWriter) Write(p []byte) (int, error) {
	n, err := cw.writer.Write(p)
	cw.written += int64(n)
	return n, err
}

/*
`files` format:

```

	map[string]string{
		"/path/on/disk/file1.txt": "file1.txt",
		"/path/on/disk/file2.txt": "subfolder/file2.txt",
		"/path/on/disk/file3.txt": "",              // put in root of archive as file3.txt
		"/path/on/disk/file4.txt": "subfolder/",    // put in subfolder as file4.txt
		"/path/on/disk/folder":    "Custom Folder", // contents added recursively
	}

```
*/
func ZipFilesWithHeaders(files map[string]string, outputFile string, headerMod HeaderModFn) (ZipStats, error) {
	path, err := filepath.Abs(outputFile)
	if err != nil {
		return ZipStats{}, err
	}
	dirname := filepath.Dir(path)
	err = os.MkdirAll(dirname, os.ModePerm)
	if err != nil {
		return ZipStats{}, err
	}

	f, err := os.Create(path)
	if err != nil {
		return ZipStats{}, err
	}
	defer f.Close()
	countedF := &CountingWriter{writer: f}
	zw := zip.NewWriter(countedF)
	defer zw.Close()

	var filesNum, bytes int64

	addFile := func(srcPath string, nameInArchive string, entry fs.DirEntry) error {
		src, err := os.Open(srcPath)
		if err != nil {
			return err
		}
		defer src.Close()

		info, err := entry.Info()
		if err != nil {
			return err
		}

		header, err := zip.FileInfoHeader(info)
		if err != nil {
			return err
		}
		header.Name = nameInArchive
		header.Method = zip.Deflate
		header = headerMod(header)
		if header.Name == "" {
			return nil
		}

		dst, err := zw.CreateHeader(header)
		if err != nil {
			return err
		}

		written, err := io.Copy(dst, src)
		if err != nil {
			return err
		}

		bytes += written
		filesNum++
		return nil
	}

	for src, dst := range files {
		stat, err := os.Stat(src)
		if err != nil {
			return ZipStats{}, err
		}

		basename := filepath.Base(src)
		if dst == "" {
			dst = basename
		} else if dst[len(dst)-1:] == "/" {
			dst = dst + basename
		}

		if !stat.IsDir() {
			addFile(src, dst, fs.FileInfoToDirEntry(stat))
			continue
		}

		err = filepath.WalkDir(src, func(path string, entry fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if entry.IsDir() {
				return nil
			}

			relativePath, err := filepath.Rel(src, path)
			if err != nil {
				return err
			}

			err = addFile(path, dst+"/"+filepath.ToSlash(relativePath), entry)
			if err != nil {
				return err
			}

			return nil
		})

		if err != nil {
			return ZipStats{}, err
		}
	}

	return ZipStats{
		FilesNum:        filesNum,
		TotalBytes:      bytes,
		CompressedBytes: countedF.written,
	}, nil
}

// If `HeaderModFn` function sets `header.Name` to empty string, file will be skipped.
type HeaderModFn func(header *zip.FileHeader) *zip.FileHeader

type ZipStats struct {
	FilesNum        int64
	TotalBytes      int64
	CompressedBytes int64
}
