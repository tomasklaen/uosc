package main

import (
	"errors"
	"os"
	"uosc/bins/src/ziggy/commands"
)

func main() {
	command := "help"
	args := os.Args[2:]

	if len(os.Args) > 1 {
		command = os.Args[1]
	}

	switch command {
	case "search-subtitles":
		commands.SearchSubtitles(args)

	case "download-subtitles":
		commands.DownloadSubtitles(args)

	case "get-clipboard":
		commands.GetClipboard(args)

	case "set-clipboard":
		commands.SetClipboard(args)

	default:
		panic(errors.New("command required"))
	}
}
