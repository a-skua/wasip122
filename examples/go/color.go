package main

import (
	"errors"
	"flag"
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"io"
	"os"
	"path/filepath"
	"strings"
)

var (
	inputPath  = flag.String("input", "", "Input image file (required)")
	outputPath = flag.String("output", "", "Output image file (required)")
	quality    = flag.Int("quality", 90, "JPEG quality (1-100, default: 90)")
	showInfo   = flag.Bool("info", false, "Show image information")
)

func init() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [options]\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "\nConvert color images to grayscale\n")
		fmt.Fprintf(os.Stderr, "\nOptions:\n")
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\nSupported formats: JPEG, PNG\n")
		fmt.Fprintf(os.Stderr, "\nExamples:\n")
		fmt.Fprintf(os.Stderr, "  %s -input photo.jpg -output gray.jpg\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s -input image.png -output result.png -info\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s -input photo.jpg -output low_quality.jpg -quality 50\n", os.Args[0])
	}

	flag.Parse()

	if *inputPath == "" || *outputPath == "" {
		fmt.Fprintf(os.Stderr, "Error: Both -input and -output are required\n\n")
		flag.Usage()
		os.Exit(1)
	}

	if *quality < 1 || *quality > 100 {
		fmt.Fprintf(os.Stderr, "Error: Quality must be between 1 and 100\n")
		os.Exit(1)
	}
}

func main() {
	// Open input file
	inputFile, err := os.Open(*inputPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error opening input file: %v\n", err)
		os.Exit(1)
	}
	defer inputFile.Close()

	// Decode image
	img, format, err := image.Decode(inputFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error decoding image: %v\n", err)
		os.Exit(1)
	}

	// Show image info if requested
	if *showInfo {
		bounds := img.Bounds()
		fmt.Printf("Image format: %s\n", format)
		fmt.Printf("Dimensions: %dx%d\n", bounds.Dx(), bounds.Dy())
		fmt.Printf("Color model: %T\n", img.ColorModel())
		os.Exit(0)
	}

	// Convert to grayscale
	bounds := img.Bounds()
	grayImg := image.NewGray(bounds)

	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			originalColor := img.At(x, y)
			grayColor := color.GrayModel.Convert(originalColor)
			grayImg.Set(x, y, grayColor)
		}
	}

	// Create output file
	outputFile, err := os.Create(*outputPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating output file: %v\n", err)
		os.Exit(1)
	}
	defer outputFile.Close()

	ext := filepath.Ext(*outputPath)
	err = writeImage(outputFile, grayImg, ext)
	// Encode and save based on output extension
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error encoding output image: %v\n", err)
		os.Exit(1)
	}

	if !*showInfo {
		fmt.Printf("Grayscale image saved to: %s\n", *outputPath)
	} else {
		fmt.Printf("Grayscale conversion completed: %s\n", *outputPath)
	}
}

func writeImage(w io.Writer, img image.Image, ext string) error {
	switch strings.ToLower(ext) {
	case ".jpg", ".jpeg":
		return jpeg.Encode(w, img, &jpeg.Options{Quality: *quality})
	case ".png":
		return png.Encode(w, img)
	default:
		var msg strings.Builder
		fmt.Fprintf(&msg, "Unsupported output format: %s\n", ext)
		fmt.Fprintf(&msg, "Use .jpg, .jpeg, or .png\n")
		return errors.New(msg.String())
	}
}
