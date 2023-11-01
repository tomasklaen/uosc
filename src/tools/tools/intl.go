package tools

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"golang.org/x/exp/maps"
	"k8s.io/apimachinery/pkg/util/sets"
)

func Intl(args []string) {
	cwd, err := os.Getwd()
	check(err)
	uoscRootRelative := "src/uosc"
	intlRootRelative := uoscRootRelative + "/intl"
	uoscRoot := filepath.Join(cwd, uoscRootRelative)

	// Check we're in correct location
	if stat, err := os.Stat(uoscRoot); os.IsNotExist(err) || !stat.IsDir() {
		fmt.Printf(`Directory "%s" doesn't exist. Make sure you're running this tool in uosc's project root folder as current working directory.`, uoscRootRelative)
		os.Exit(1)
	}

	// Help
	if len(args) < 1 || len(args) > 0 && sets.New("--help", "-h").Has(args[0]) {
		fmt.Printf(`Updates or creates a localization files by parsing the codebase for localization strings, and (re)constructing the locale files with them.
Strings no longer in use are removed. Strings not yet translated are set to "null".

Usage:

  intl [languages]

Parameters:

  languages    A comma separated list of language codes to update
               or create. Use 'all' to update all existing locales.

Examples:

  > intl xy
  Create a new locale xy.

  > intl de,es
  Update de and es locales.

  > intl all
  Update everything inside "%s".

`, intlRootRelative)
		os.Exit(0)
	}

	var locales []string
	if args[0] == "all" {
		intlRoot := filepath.Join(cwd, intlRootRelative)
		locales = must(listFilenamesOfType(intlRoot, ".json"))
	} else {
		locales = strings.Split(args[0], ",")
	}

	holePunchLocales(locales, uoscRoot)
}

func holePunchLocales(locales []string, rootPath string) {
	fmt.Println("Creating localization holes for:", strings.Join(locales, ", "))

	fnName := 't'
	spaces := sets.New(' ', '\t', '\n')
	enclosers := sets.New('"', '\'')
	wordBreaks := sets.New('=', '*', '+', '-', '/', '(', ')', '^', '%', '#', '@', '!', '~', '`', '"', '\'', ' ', '\t', '\n')
	escape := '\\'
	openParen := '('
	localizationStrings := sets.New[string]()

	// Contents processor to extract localization strings
	// Solution doesn't check if function calls are commented out or not.
	processFile := func(path string) {
		escapesNum := 0
		f := must(os.Open(path))
		currentStr := ""
		currentEncloser := '"'
		prevRune := ' '

		type lexFn func(r rune)
		var currentLexer lexFn
		var accumulateString lexFn
		var findOpenEncloser lexFn
		var findOpenParen lexFn
		var findFn lexFn

		commitStr := func() {
			localizationStrings.Insert(currentStr)
			currentStr = ""
			currentLexer = findFn
		}

		accumulateString = func(r rune) {
			if r == currentEncloser && escapesNum%2 == 0 {
				commitStr()
			} else {
				if r == escape {
					escapesNum++
				} else {
					escapesNum = 0
				}
				currentStr += string(r)
			}
		}

		findOpenEncloser = func(r rune) {
			if !spaces.Has(r) {
				if enclosers.Has(r) {
					currentEncloser = r
					currentLexer = accumulateString
				} else {
					currentLexer = findFn
				}
			}
		}

		findOpenParen = func(r rune) {
			if !spaces.Has(r) {
				if r == openParen {
					currentLexer = findOpenEncloser
				} else {
					currentLexer = findFn
				}
			}
		}

		findFn = func(b rune) {
			if b == fnName && wordBreaks.Has(prevRune) {
				currentLexer = findOpenParen
			}
		}

		currentLexer = findFn
		br := bufio.NewReader(f)

		for {
			r, _, err := br.ReadRune()

			if err != nil && !errors.Is(err, io.EOF) {
				panic(err)
			}

			// end of file
			if err != nil {
				break
			}

			currentLexer(r)

			prevRune = r
			escapesNum = 0
		}
	}

	// Find localization strings in lua files
	check(filepath.WalkDir(rootPath, func(fp string, fi os.DirEntry, err error) error {
		check(err)

		if ext := filepath.Ext(fp); ext == ".lua" {
			processFile(fp)
		}

		return nil
	}))

	fmt.Println("Found localization strings:", localizationStrings.Len())

	// Create new or punch holes and filter unused strings from existing locales
	for _, locale := range locales {
		localePath := filepath.Join(rootPath, "intl", locale+".json")
		isNew := true

		// Parse old json
		oldLocaleData := make(map[string]interface{})
		localeContents, err := os.ReadFile(localePath)
		if err == nil {
			isNew = false
			check(json.Unmarshal(localeContents, &oldLocaleData))
		} else if !errors.Is(err, os.ErrNotExist) {
			check(err)
		}

		// Merge into new locale for current codebase
		var localeData = make(map[string]interface{})
		removed := sets.List(sets.New[string](maps.Keys(oldLocaleData)...).Difference(localizationStrings))
		untranslated := []string{}

		for _, str := range sets.List(localizationStrings) {
			if old, ok := oldLocaleData[str]; ok {
				localeData[str] = old
			} else {
				localeData[str] = nil
			}

			if localeData[str] == nil {
				untranslated = append(untranslated, str)
			}
		}

		// Output
		resultJson := must(JSONMarshalIndent(localeData, "", "\t"))
		check(os.WriteFile(localePath, resultJson, 0644))
		fmt.Println()

		// Stats
		newOrUpdatingMsg := "Updating existing locale"
		if len(removed) == 0 && len(untranslated) == 0 {
			newOrUpdatingMsg = "Locale is up to date"
		} else if isNew {
			newOrUpdatingMsg = "Creating new locale"
		}
		fmt.Println("[[", locale, "]]>", newOrUpdatingMsg)
		if len(removed) > 0 {
			fmt.Println("• Removed:")
			for _, str := range removed {
				fmt.Printf("  '%s'\n", str)
			}
		}
		if len(untranslated) > 0 {
			fmt.Println("• Untranslated:")
			for _, str := range untranslated {
				fmt.Printf("  '%s'\n", str)
			}
		}
	}
}

func listFilenamesOfType(directoryPath string, extension string) ([]string, error) {
	files := []string{}
	extension = strings.ToLower(extension)

	dirEntries, err := os.ReadDir(directoryPath)
	if err != nil {
		return nil, err
	}

	for _, entry := range dirEntries {
		if entry.IsDir() {
			continue
		}
		filename := entry.Name()
		ext := filepath.Ext(filename)
		if strings.ToLower(ext) == extension {
			files = append(files, filename[:len(filename)-len(ext)])
		}
	}

	return files, nil
}

// Because the default `json.Marshal` HTML escapes `&,<,>` characters and it can't be turned off...
func JSONMarshalIndent(t interface{}, prefix string, indent string) ([]byte, error) {
	buffer := &bytes.Buffer{}
	encoder := json.NewEncoder(buffer)
	encoder.SetEscapeHTML(false)
	encoder.SetIndent(prefix, indent)
	err := encoder.Encode(t)
	return buffer.Bytes(), err
}
