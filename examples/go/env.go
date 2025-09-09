package main

import (
	"fmt"
	"os"
)

func main() {
	env := os.Environ()
	fmt.Println(env)
}
