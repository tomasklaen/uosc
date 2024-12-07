package commands

import (
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"

	"uosc/bins/src/ziggy/lib"
)

type HTTPResult struct {
	Headers http.Header `json:"headers"`
	Status  int         `json:"status"`
	Body    string      `json:"body"`
}

func Http(method string, args []string) {
	cmd := flag.NewFlagSet("http-get", flag.ExitOnError)
	argHeaders := cmd.String("headers", "", "HTTP GET headers as JSON.")
	argBody := cmd.String("body", "", "HTTP GET body.")
	defaultHeaders := map[string]string{
		"User-Agent": "uosc/ziggy",
		"Accept":     "application/json",
	}

	lib.Check(cmd.Parse(args))

	values := cmd.Args()
	if len(values) < 1 {
		lib.Check(errors.New("missing URL parameter"))
	}
	if len(values) > 1 {
		lib.Check(fmt.Errorf("multiple URL parameters received: %v", values))
	}

	url := values[0]

	// Process JSON headers
	headers := defaultHeaders
	if argHeaders != nil && *argHeaders != "" {
		customHeaders := make(map[string]string)
		lib.Check(json.Unmarshal([]byte(*argHeaders), &customHeaders))

		for key, value := range customHeaders {
			headers[key] = value
		}
	}

	// Set up the request body if provided
	var bodyReader *bytes.Reader
	if argBody != nil {
		bodyReader = bytes.NewReader([]byte(*argBody))
	} else {
		bodyReader = bytes.NewReader(nil)
	}

	// Create an HTTP request
	req := lib.Must(http.NewRequest(method, url, bodyReader))
	for key, value := range headers {
		req.Header.Set(key, value)
	}

	// Create an HTTP client and make the request
	client := &http.Client{}
	resp := lib.Must(client.Do(req))
	defer resp.Body.Close()

	// Output the response
	fmt.Print(string(lib.Must(lib.JSONMarshal(HTTPResult{
		Status:  resp.StatusCode,
		Headers: resp.Header,
		Body:    string(lib.Must(io.ReadAll(resp.Body))),
	}))))
}
