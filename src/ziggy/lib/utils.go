package lib

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"os"
)

type ErrorData struct {
	Error   bool   `json:"error"`
	Message string `json:"message"`
}

func Check(err error) {
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

func Must[T any](t T, err error) T {
	Check(err)
	return t
}

const OSDBChunkSize = 65536 // 64k

// Generate an OSDB hash for a file.
func OSDBHashFile(filePath string) (hash string, err error) {
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

// Read a chunk of a file at `offset` so as to fill `buf`.
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
