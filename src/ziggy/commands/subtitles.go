package commands

import (
	"bytes"
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

	"uosc/bins/src/ziggy/lib"
)

const OPEN_SUBTITLES_API_URL = "https://api.opensubtitles.com/api/v1"

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

func SearchSubtitles(args []string) {
	cmd := flag.NewFlagSet("search-subtitles", flag.ExitOnError)
	argApiKey := cmd.String("api-key", "", "Open Subtitles consumer API key.")
	argAgent := cmd.String("agent", "", "User-Agent header. Format: appname v1.0")
	argLanguages := cmd.String("languages", "", "What languages to search for.")
	argHash := cmd.String("hash", "", "What file to hash and add to search query.")
	argQuery := cmd.String("query", "", "String query to use.")
	argPage := cmd.Int("page", 1, "Results page, starting at 1.")

	lib.Check(cmd.Parse(args))

	// Validation
	if len(*argApiKey) == 0 {
		lib.Check(errors.New("--api-key is required"))
	}
	if len(*argAgent) == 0 {
		lib.Check(errors.New("--agent is required"))
	}
	if len(*argHash) == 0 && len(*argQuery) == 0 {
		lib.Check(errors.New("at least one of --query or --hash is required"))
	}
	if len(*argLanguages) == 0 {
		lib.Check(errors.New("--languages is required"))
	}

	// "Send request parameters sorted, and send all queries in lowercase."
	params := []string{}
	languageDelimiterRE := regexp.MustCompile(" *, *")
	languages := languageDelimiterRE.Split(*argLanguages, -1)
	slices.Sort(languages)
	params = append(params, "languages="+escapeParam(strings.Join(languages, ",")))
	if len(*argHash) > 0 {
		hash, err := lib.OSDBHashFile(*argHash)
		if err == nil {
			params = append(params, "moviehash="+escapeParam(hash))
		} else if len(*argQuery) == 0 {
			lib.Check(fmt.Errorf("couldn't hash the file (%w) and query is empty", err))
		}
	}
	params = append(params, "page="+escapeParam(fmt.Sprint(*argPage)))
	if len(*argQuery) > 0 {
		params = append(params, "query="+escapeParam(*argQuery))
	}

	client := http.Client{}
	req := lib.Must(http.NewRequest("GET", OPEN_SUBTITLES_API_URL+"/subtitles?"+strings.Join(params, "&"), nil))
	req.Header = http.Header{
		"Api-Key":    {*argApiKey},
		"User-Agent": {*argAgent},
	}

	resp := lib.Must(client.Do(req))
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		fmt.Print(string(lib.Must(io.ReadAll(resp.Body))))
	} else {
		lib.Check(errors.New(resp.Status))
	}
}

func DownloadSubtitles(args []string) {
	cmd := flag.NewFlagSet("download-subtitles", flag.ExitOnError)
	argApiKey := cmd.String("api-key", "", "Open Subtitles consumer API key.")
	argAgent := cmd.String("agent", "", "User-Agent header. Format: appname v1.0")
	argFileID := cmd.Int("file-id", 0, "Subtitle file ID to download.")
	argDestination := cmd.String("destination", "", "Destination directory.")

	lib.Check(cmd.Parse(args))

	// Validation
	if len(*argApiKey) == 0 {
		lib.Check(errors.New("--api-key is required"))
	}
	if len(*argAgent) == 0 {
		lib.Check(errors.New("--agent is required"))
	}
	if *argFileID == 0 {
		lib.Check(errors.New("--file-id is required"))
	}
	if len(*argDestination) == 0 {
		lib.Check(errors.New("--destination is required"))
	}

	// Create the directory if it doesn't exist
	if _, err := os.Stat(*argDestination); os.IsNotExist(err) {
		os.MkdirAll(*argDestination, 0755)
	}

	data := bytes.NewBuffer(lib.Must(lib.JSONMarshal(DownloadRequestData{FileId: *argFileID})))
	client := http.Client{}
	req := lib.Must(http.NewRequest("POST", OPEN_SUBTITLES_API_URL+"/download", data))
	req.Header = http.Header{
		"Accept":       {"application/json"},
		"Api-Key":      {*argApiKey},
		"Content-Type": {"application/json"},
		"User-Agent":   {*argAgent},
	}

	resp := lib.Must(client.Do(req))
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		lib.Check(errors.New(resp.Status))
	}
	var downloadData DownloadResponseData
	lib.Check(json.Unmarshal(lib.Must(io.ReadAll(resp.Body)), &downloadData))
	filePath := filepath.Join(*argDestination, downloadData.FileName)
	outFile := lib.Must(os.Create(filePath))
	defer outFile.Close()

	response := lib.Must(http.Get(downloadData.Link))
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		lib.Check(fmt.Errorf("downloading failed: %s", response.Status))
	}

	lib.Must(io.Copy(outFile, response.Body))

	fmt.Print(string(lib.Must(lib.JSONMarshal(DownloadData{
		File:      filePath,
		Remaining: downloadData.Remaining,
		Total:     downloadData.Remaining + downloadData.Requests,
		ResetTime: downloadData.ResetTime,
	}))))
}

// Escape and lowercase (open subtitles requirement) a URL parameter
func escapeParam(str string) string {
	return url.QueryEscape(strings.ToLower(str))
}
