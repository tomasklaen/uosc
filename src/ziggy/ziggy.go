package main

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
)

const OPEN_SUBTITLES_API_URL = "https://api.opensubtitles.com/api/v1"
const OSDBChunkSize = 65536 // 64k

func main() {
	srSubsCmd := flag.NewFlagSet("search-subtitles", flag.ExitOnError)
	srSubsApiKey := srSubsCmd.String("api-key", "", "Open Subtitles consumer API key.")
	srSubsAgent := srSubsCmd.String("agent", "", "User-Agent header. Format: appname v1.0")
	srSubsLanguages := srSubsCmd.String("languages", "", "What languages to search for.")
	srSubsHash := srSubsCmd.String("hash", "", "What file to hash and add to search query.")
	srSubsQuery := srSubsCmd.String("query", "", "String query to use.")
	srSubsPage := srSubsCmd.Int("page", 1, "Results page, starting at 1.")

	dlSubsCmd := flag.NewFlagSet("download-subtitles", flag.ExitOnError)
	dlSubsApiKey := dlSubsCmd.String("api-key", "", "Open Subtitles consumer API key.")
	dlSubsAgent := dlSubsCmd.String("agent", "", "User-Agent header. Format: appname v1.0")
	dlSubsID := dlSubsCmd.Int("file-id", 0, "Subtitle file ID to download.")
	dlSubsDestination := dlSubsCmd.String("destination", "", "Destination directory.")

	if len(os.Args) <= 1 {
		panic(errors.New("command required"))
	}

	switch os.Args[1] {
	case "search-subtitles":
		check(srSubsCmd.Parse(os.Args[2:]))

		// Validation
		if len(*srSubsApiKey) == 0 {
			check(errors.New("--api-key is required"))
		}
		if len(*srSubsAgent) == 0 {
			check(errors.New("--agent is required"))
		}
		if len(*srSubsHash) == 0 && len(*srSubsQuery) == 0 {
			check(errors.New("at least one of --query or --hash is required"))
		}
		if len(*srSubsLanguages) == 0 {
			check(errors.New("--languages is required"))
		}

		// "Send request parameters sorted, and send all queries in lowercase."
		params := []string{}
		languageDelimiterRE := regexp.MustCompile(" *, *")
		languages := languageDelimiterRE.Split(*srSubsLanguages, -1)
		slices.Sort(languages)
		params = append(params, "languages="+escape(strings.Join(languages, ",")))
		if len(*srSubsHash) > 0 {
			params = append(params, "moviehash="+escape(must(hashFile(*srSubsHash))))
		}
		params = append(params, "page="+escape(fmt.Sprint(*srSubsPage)))
		if len(*srSubsQuery) > 0 {
			params = append(params, "query="+escape(*srSubsQuery))
		}

		client := http.Client{}
		req := must(http.NewRequest("GET", OPEN_SUBTITLES_API_URL+"/subtitles?"+strings.Join(params, "&"), nil))
		req.Header = http.Header{
			"Api-Key":    {*srSubsApiKey},
			"User-Agent": {*srSubsAgent},
		}

		resp := must(client.Do(req))
		defer resp.Body.Close()

		if resp.StatusCode == http.StatusOK {
			fmt.Print(string(must(io.ReadAll(resp.Body))))
		} else {
			check(errors.New(resp.Status))
		}

	case "download-subtitles":
		check(dlSubsCmd.Parse(os.Args[2:]))

		// Validation
		if len(*dlSubsApiKey) == 0 {
			check(errors.New("--api-key is required"))
		}
		if len(*dlSubsAgent) == 0 {
			check(errors.New("--agent is required"))
		}
		if *dlSubsID == 0 {
			check(errors.New("--file-id is required"))
		}
		if len(*dlSubsDestination) == 0 {
			check(errors.New("--destination is required"))
		}

		// Create the directory if it doesn't exist
		if _, err := os.Stat(*dlSubsDestination); os.IsNotExist(err) {
			os.MkdirAll(*dlSubsDestination, 0755)
		}

		data := bytes.NewBuffer(must(JSONMarshal(DownloadRequestData{FileId: *dlSubsID})))
		client := http.Client{}
		req := must(http.NewRequest("POST", OPEN_SUBTITLES_API_URL+"/download", data))
		req.Header = http.Header{
			"Accept":       {"application/json"},
			"Api-Key":      {*dlSubsApiKey},
			"Content-Type": {"application/json"},
			"User-Agent":   {*dlSubsAgent},
		}

		resp := must(client.Do(req))
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			check(errors.New(resp.Status))
		}
		var downloadData DownloadResponseData
		check(json.Unmarshal(must(io.ReadAll(resp.Body)), &downloadData))
		filePath := filepath.Join(*dlSubsDestination, downloadData.FileName)
		outFile := must(os.Create(filePath))
		defer outFile.Close()

		response := must(http.Get(downloadData.Link))
		defer response.Body.Close()

		if response.StatusCode != http.StatusOK {
			check(fmt.Errorf("downloading failed: %s", response.Status))
		}

		must(io.Copy(outFile, response.Body))

		fmt.Print(string(must(JSONMarshal(DownloadData{
			File:      filePath,
			Remaining: downloadData.Remaining,
			Total:     downloadData.Remaining + downloadData.Requests,
			ResetTime: downloadData.ResetTime,
		}))))
	}
}

type DownloadRequestData struct {
	FileId int `json:"file_id"`
}

type DownloadResponseData struct {
	Link         string `json:"link"`
	FileName     string `json:"file_name"`
	Requests     int    `json:"requests"`
	Remaining    int    `json:"remaining"`
	Message      string `json:"message"`
	ResetTime    string `json:"reset_time"`
	ResetTimeUTC string `json:"reset_time_utc"`
}

type DownloadData struct {
	File      string `json:"file"`
	Remaining int    `json:"remaining"`
	Total     int    `json:"total"`
	ResetTime string `json:"reset_time"`
}

type ErrorData struct {
	Error   bool   `json:"error"`
	Message string `json:"message"`
}

func check(err error) {
	if err != nil {
		res := ErrorData{Error: true, Message: err.Error()}
		json, err := json.Marshal(res)
		if err != nil {
			panic(err)
		}
		fmt.Print(string(json))
		os.Exit(0)
	}
}

func must[T any](t T, err error) T {
	check(err)
	return t
}

// Escape and lowercase (open subtitles requirement) a URL parameter
func escape(str string) string {
	return url.QueryEscape(strings.ToLower(str))
}

// Generate an OSDB hash for a file
func hashFile(filePath string) (hash string, err error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", errors.New("couldn't open file for hashing")
	}

	fi, err := file.Stat()
	if err != nil {
		return "", errors.New("couldn't stat file for hashing")
	}
	if fi.Size() < OSDBChunkSize {
		return "", errors.New("file is too small to generate a valid OSDB hash")
	}

	// Read head and tail blocks
	buf := make([]byte, OSDBChunkSize*2)
	err = readChunk(file, 0, buf[:OSDBChunkSize])
	if err != nil {
		return
	}
	err = readChunk(file, fi.Size()-OSDBChunkSize, buf[OSDBChunkSize:])
	if err != nil {
		return
	}

	// Convert to uint64, and sum
	var nums [(OSDBChunkSize * 2) / 8]uint64
	reader := bytes.NewReader(buf)
	err = binary.Read(reader, binary.LittleEndian, &nums)
	if err != nil {
		return "", err
	}
	var hashUint uint64
	for _, num := range nums {
		hashUint += num
	}

	hashUint = hashUint + uint64(fi.Size())

	return fmt.Sprintf("%016x", hashUint), nil
}

// Read a chunk of a file at `offset` so as to fill `buf`
func readChunk(file *os.File, offset int64, buf []byte) (err error) {
	n, err := file.ReadAt(buf, offset)
	if err != nil {
		return err
	}
	if n != OSDBChunkSize {
		return fmt.Errorf("invalid read %v", n)
	}
	return
}

// Because the default `json.Marshal` HTML escapes `&,<,>` characters and it can't be turned off...
func JSONMarshal(t interface{}) ([]byte, error) {
	buffer := &bytes.Buffer{}
	encoder := json.NewEncoder(buffer)
	encoder.SetEscapeHTML(false)
	err := encoder.Encode(t)
	return buffer.Bytes(), err
}
