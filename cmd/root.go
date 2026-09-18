package cmd

import (
	"errors"
	"fmt"
	"os"
	"wut/internal/search"
	"wut/internal/ui"

	"github.com/atotto/clipboard"
	"github.com/spf13/cobra"
)

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
	Args:          cobra.MinimumNArgs(1),
	SilenceErrors: true,
	RunE: func(cmd *cobra.Command, args []string) error {
		cmd.SilenceUsage = true

		return run(search.NewQuery(args))
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

// run turns a query into the thing the user asked for: the search itself is
// internal/search's job, everything below is this command's.
func run(query search.Query) error {
	results, warnings, err := search.Find(query)
	if err != nil {
		return err
	}

	for _, e := range warnings {
		fmt.Fprintln(os.Stderr, "warning:", e) // some worked: degrade
	}

	// Finding nothing is a normal outcome of a search, not a failure: report it
	// and exit 0. Going further would open a picker with no index to return.
	if len(results) == 0 {
		fmt.Fprintf(os.Stderr, "no matches for %q\n", query.Joined)
		return nil
	}

	// Built from the ranked slice, and read back by index at the bottom of this
	// function: the two slices have to stay in the same order.
	choices := make([]ui.Choice, len(results))
	for i, r := range results {
		choices[i] = ui.Choice{Title: r.Cmd, Desc: r.Desc}
	}

	idx, err := ui.Pick("Results", choices)
	if err != nil {
		if errors.Is(err, ui.ErrAborted) {
			return nil // user quit; exit 0
		}
		return fmt.Errorf("picker: %w", err)
	}

	selected := results[idx]

	err = clipboard.WriteAll(selected.Cmd)

	if err != nil {
		return fmt.Errorf("clipboard writeall: %w", err)
	}

	// No leading newline: the erase leaves the cursor on the frame's blank
	// first row, so this lands directly under the invoking command line.
	fmt.Printf("🚀 Copied to clipboard: %s\n", selected.Cmd)

	return nil
}
