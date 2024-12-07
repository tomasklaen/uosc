package commands

import (
	"flag"
	"fmt"
	"uosc/bins/src/ziggy/lib"

	"github.com/pkg/browser"
)

type OpenResult struct {
	Payload string `json:"payload"`
}

func Open(args []string) {
	cmd := flag.NewFlagSet("open", flag.ExitOnError)

	lib.Check(cmd.Parse(args))

	values := cmd.Args()
	if len(values) != 1 {
		lib.Check(fmt.Errorf("only one path or URL expected, but %v received", len(values)))
	}
	value := values[0]

	lib.Check(browser.OpenURL(value))

	fmt.Print(string(lib.Must(lib.JSONMarshal(ClipboardResult{
		Payload: value,
	}))))
}
