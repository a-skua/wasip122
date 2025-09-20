package main

import (
	"fmt"
	"io"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <file1> [file2 ...]\n", os.Args[0])
		os.Exit(1)
	}

	for _, filename := range os.Args[1:] {
		err := cat(filename)
		if err != nil {
			fmt.Fprintf(os.Stderr, err.Error())
		}
	}
}

func cat(filename string) error {
	file, err := os.Open(filename)
	if err != nil {
		return fmt.Errorf("Error opening %s: %v\n", filename, err)
	}
	defer file.Close()

	_, err = io.Copy(os.Stdout, file)
	if err != nil {
		return fmt.Errorf("Error reading %s: %v\n", filename, err)
	}

	return nil
}
