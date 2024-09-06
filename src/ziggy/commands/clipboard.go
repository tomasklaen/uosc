package commands

import (
	"errors"
	"flag"
	"fmt"
	"strings"
	"uosc/bins/src/ziggy/lib"

	"github.com/atotto/clipboard"
)

type ClipboardResult struct {
	Payload string `json:"payload"`
}

func GetClipboard(_ []string) {
	// We need to do this instead of just `Payload: lib.Must(clipboard.ReadAll())` because
	// the atotto/clipboard returns unhelpful messages like "the operation completed successfully".
	payload, err := clipboard.ReadAll()
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "successfully") {
			lib.Check(errors.New("clipboard format not supported"))
		}
		lib.Check(err)
	}

	fmt.Print(string(lib.Must(lib.JSONMarshal(ClipboardResult{
		Payload: payload,
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
