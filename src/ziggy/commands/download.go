package commands

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"uosc/bins/src/ziggy/lib"
)

type DownloadResult struct {
	Url      string `json:"url"`
	Path     string `json:"path"`
	Filename string `json:"filename"` // Filename suggested by disposition header. Can be empty.
}

func Download(args []string) {
	cmd := flag.NewFlagSet("download", flag.ExitOnError)
	argUrl := cmd.String("url", "", "File URL.")
	argPath := cmd.String("path", "", "File destination path.")

	lib.Check(cmd.Parse(args))

	// Validation
	if len(*argUrl) == 0 {
		lib.Check(errors.New("--url is required"))
	}
	if len(*argPath) == 0 {
		lib.Check(errors.New("--path is required"))
	}

	// Download & output the response
	fmt.Print(string(lib.Must(lib.JSONMarshal(DownloadResult{
		Url:      *argUrl,
		Path:     *argPath,
		Filename: lib.Must(downloadFile(*argUrl, *argPath)),
	}))))
}

// Downloads file form URL to a filePath and returns a filename suggested by disposition header.
func downloadFile(url, filePath string) (string, error) {
	// Ensure the directory exists
	dir := filepath.Dir(filePath)
	if err := os.MkdirAll(dir, os.ModePerm); err != nil {
		return "", fmt.Errorf("failed to create directory %s: %w", dir, err)
	}

	// Make HTTP request
	resp, err := http.Get(url)
	if err != nil {
		return "", fmt.Errorf("failed to fetch URL: %w", err)
	}
	defer resp.Body.Close()

	// Check for HTTP errors
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("non-OK HTTP status: %d %s", resp.StatusCode, resp.Status)
	}

	// Create the file
	out, err := os.Create(filePath)
	if err != nil {
		return "", fmt.Errorf("failed to create file: %w", err)
	}
	defer out.Close()

	// Write response body to file
	_, err = io.Copy(out, resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to write file: %w", err)
	}

	// Extract file name from Content-Disposition header
	return getFileNameFromHeader(resp.Header.Get("Content-Disposition")), nil
}

// Extracts the file name from the Content-Disposition header.
func getFileNameFromHeader(header string) string {
	if header == "" {
		return ""
	}

	const prefix = "filename="
	for _, part := range strings.Split(header, ";") {
		part = strings.TrimSpace(part)
		if strings.HasPrefix(part, prefix) {
			// Remove the prefix and any surrounding quotes
			return strings.Trim(part[len(prefix):], `"`)
		}
	}
	return ""
}
