package commands

import (
	"flag"
	"fmt"
	"uosc/bins/src/ziggy/lib"

	"github.com/atotto/clipboard"
)

type ClipboardResult struct {
	Payload string `json:"payload"`
}

func GetClipboard(_ []string) {
	fmt.Print(string(lib.Must(lib.JSONMarshal(ClipboardResult{
		Payload: lib.Must(clipboard.ReadAll()),
	}))))
}

func SetClipboard(args []string) {
	cmd := flag.NewFlagSet("set-clipboard", flag.ExitOnError)

	lib.Check(cmd.Parse(args))

	values := cmd.Args()
	value := ""
	if len(values) > 0 {
		value = values[0]
	}

	lib.Check(cmd.Parse(args))

	lib.Check(clipboard.WriteAll(value))

	fmt.Print(string(lib.Must(lib.JSONMarshal(ClipboardResult{
		Payload: value,
	}))))
}
