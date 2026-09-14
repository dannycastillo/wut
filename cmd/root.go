/*
Copyright © 2026 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"strings"
	"sync"

	"github.com/atotto/clipboard"
	"github.com/manifoldco/promptui"
	"github.com/spf13/cobra"
)

type Result struct {
	Desc  string
	Cmd   string
	Score int
}

type Query struct {
	Joined string
	Split  []string
}

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "wut",
	Short: "Search for command line snippets",
	Long: `Wut is a search utility that lets you find terminal commands
from perviously curated notes. Store a txt file in a ~/.wut
directory that follows the following basic format:


# check size of a directory
du -sh DIR

# list largest items in current directory
du -sh * | sort -rh | head -n 10


Then you can call the wut command followed by a search phrase to 
recall what the commands are. For example the following query:

wut directory size

will return the following results in a UI picker:

du -sh DIR   # check size of a directory

The goal is to make it easiy to quickly recall and copy commands when working
in shell environments.`,
	Args: cobra.ArbitraryArgs,
	Run: func(cmd *cobra.Command, args []string) {
		// 'args' captures all arbitrary positional arguments
		for i := range args {
			args[i] = strings.ToLower(args[i])
		}

		query := Query{
			Joined: strings.Join(args, " "),
			Split:  args,
		}

		searchManager(query)
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

func init() {
	// Here you will define your flags and configuration settings.
	// Cobra supports persistent flags, which, if defined here,
	// will be global for your application.

	// rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.wut-command.yaml)")

	// Cobra also supports local flags, which will only run
	// when this action is called directly.
	rootCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}

func searchManager(query Query) {
	files := listFiles()

	// 1. Create a channel to collect results
	resultsChan := make(chan Result)
	var wg sync.WaitGroup

	// 2. Launch child functions concurrently
	wg.Add(len(files))

	for _, v := range files {
		go scanFile(v, query, resultsChan, &wg)
	}

	// 3. Close the channel once all children are completely done
	go func() {
		wg.Wait()
		close(resultsChan)
	}()

	// 4. Collect results into the root slice safely (no data race)
	var finalResults []Result
	for r := range resultsChan {
		finalResults = append(finalResults, r)

		//fmt.Printf("MatchScore %d\n%s  %s\n\n", r.Score, r.Cmd, r.Desc)
	}

	// fmt.Println("Query Complete: ", query.Joined)

	// Build UI
	// ========

	var options []string

	for _, v := range finalResults {
		option := fmt.Sprintf("%s %s", v.Cmd, v.Desc)
		options = append(options, option)
	}

	prompt := promptui.Select{
		Label: "Select a Deployment Environment",
		Items: options,
		Size:  10, // Number of items visible at once before scrolling
	}

	index, _, err := prompt.Run()

	if err != nil {
		// Handles cases where user exits early (e.g., presses Ctrl+C)
		fmt.Printf("\nPrompt cancelled: %v\n", err)
		return
	}

	selectedOption := finalResults[index]

	// copy to keyboard
	// One line of code to copy text
	err = clipboard.WriteAll(selectedOption.Cmd)
	if err != nil {
		fmt.Println("Failed to copy:", err)
		return
	}

	fmt.Printf("\n🚀 Copied to clipboard: %s\n", selectedOption.Cmd)
}

func listFiles() []string {
	return []string{"internal/data.txt"}
}

func scanFile(filepath string, query Query, ch chan<- Result, wg *sync.WaitGroup) {
	defer wg.Done()

	file, err := os.Open(filepath)

	if err != nil {
		fmt.Printf("Error opening file %s: %v\n", filepath, err)
		return
	}

	defer file.Close()

	scanner := bufio.NewScanner(file)

	multiByteDelimiter := []byte("\n#")

	scanner.Split(func(data []byte, atEOF bool) (advance int, token []byte, err error) {
		if atEOF && len(data) == 0 {
			return 0, nil, nil
		}

		if i := bytes.Index(data, multiByteDelimiter); i >= 0 {
			// Move the read pointer past the chunk and the delimiter length
			return i + 1, data[0:i], nil
		}

		if atEOF {
			return len(data), data, nil
		}

		return 0, nil, nil
	})

	chunkNumber := 1
	for scanner.Scan() {

		matches := scanChunk(query, scanner.Text())

		for _, v := range matches {
			ch <- v
		}

		chunkNumber++
	}

	if err := scanner.Err(); err != nil {
		fmt.Printf("Error reading file content: %v\n", err)
	}
}

func scanChunk(query Query, chunk string) []Result {
	var matches []Result

	// Scoring System
	// Direct Match = 1000
	// Word Match = 500 + 5 per matching word

	// Direct Match
	if strings.Contains(chunk, query.Joined) {
		score := 1000
		matches = append(matches, buildMatch(chunk, score))
	} else {
		// Word Match
		wordMatches := countMatches(strings.Fields(chunk), query.Split)

		if wordMatches > 0 {
			score := 500 + (wordMatches * 5)
			matches = append(matches, buildMatch(chunk, score))
		}
	}

	return matches
}

func countMatches(slice1, slice2 []string) int {
	// Step 1: Populate a map with items from the first slice
	seen := make(map[string]bool)
	for _, item := range slice1 {
		seen[item] = true
	}

	// Step 2: Loop through the second slice and count matches
	matchCount := 0
	for _, item := range slice2 {
		if seen[item] {
			matchCount++
			// Optional: Delete the item if you only want to count unique matches
			// delete(seen, item)
		}
	}

	return matchCount
}

func buildMatch(chunk string, score int) Result {
	result := Result{
		Score: score,
	}

	lines := strings.Split(chunk, "\n")

	for _, line := range lines {
		if strings.HasPrefix(line, "#") {
			result.Desc += line
		} else {
			result.Cmd += line
		}
	}

	return result
}
