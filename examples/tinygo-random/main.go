package main

import (
	"crypto/rand"
	"fmt"
	"os"
)

func main() {
	// Force random number generation
	buf := make([]byte, 8)
	n, err := rand.Read(buf)
	if err != nil {
		fmt.Printf("Error reading random: %v\n", err)
		os.Exit(1)
	}
	
	fmt.Printf("Args: %v\n", os.Args)
	fmt.Printf("Random bytes (%d): %v\n", n, buf)
}