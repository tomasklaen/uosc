package main

import (
	"fmt"
	"os"
	"uosc/bins/src/tools/tools"
)

func main() {
	command := "help"

	if len(os.Args) > 1 {
		command = os.Args[1]
	}

	switch command {
	case "intl":
		tools.Intl(os.Args[2:])

	case "package":
		tools.Packager(os.Args[2:])

	// Help
	default:
		fmt.Printf(`uosc tools.

Usage:

  tools <command> [args]

Available <command>s:

  intl - localization helper
  package - package uosc release files

Run 'tools <command> -h/--help' for help on how to use each tool.
`)
	}
}
