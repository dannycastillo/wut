// Package cmd is the wut command line: it runs the search, shows the picker
// and copies the chosen command to the clipboard.
package cmd

import (
	"errors"
	"fmt"
	"os"
	"wut/internal/search"
	"wut/internal/ui"

	"charm.land/lipgloss/v2"
	"github.com/atotto/clipboard"
	"github.com/charmbracelet/colorprofile"
	"github.com/spf13/cobra"
)

// ANSI 2, not a hex value: the theme's own green reads on any background.
var copiedMark = lipgloss.NewStyle().Foreground(lipgloss.Color("2")).Render("✔")

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

// Execute runs the root command and exits 1 if it fails.
func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func run(query search.Query) error {
	results, warnings, err := search.Find(query)
	if err != nil {
		return err
	}

	for _, e := range warnings {
		fmt.Fprintln(os.Stderr, "warning:", e) // some worked: degrade
	}

	// No results is a normal outcome, not a failure: report it and exit 0.
	if len(results) == 0 {
		fmt.Fprintf(os.Stderr, "No Results Found For: %s\n", query.Joined)
		return nil
	}

	// Read back by index below: choices and results must stay in the same order.
	choices := make([]ui.Choice, len(results))
	for i, r := range results {
		choices[i] = ui.Choice{Title: r.Cmd, Desc: r.Desc}
	}

	idx, err := ui.Pick(choices)
	if err != nil {
		if errors.Is(err, ui.ErrAborted) {
			return nil // nothing selected; exit 0
		}
		return fmt.Errorf("picker: %w", err)
	}

	selected := results[idx]

	err = clipboard.WriteAll(selected.Cmd)

	if err != nil {
		return fmt.Errorf("clipboard writeall: %w", err)
	}

	// No leading newline: the picker's erase leaves the cursor on the frame's
	// blank first row. colorprofile strips the colour when stdout is not a tty.
	fmt.Fprintf(colorprofile.NewWriter(os.Stdout, os.Environ()),
		"%s Copied: %s\n", copiedMark, selected.Cmd)

	return nil
}
