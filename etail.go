// Copyright (c) 2020, The Emergent Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"
	"log"
	"os"

	"github.com/nsf/termbox-go"
)

func main() {
	err := termbox.Init()
	if err != nil {
		log.Println(err)
		panic(err)
	}
	defer termbox.Close()

	TheFiles.Open(os.Args[1:])

	if len(TheFiles) == 0 {
		fmt.Printf("usage: etail <filename>...  (space separated)\n")
		return
	}

	err = TheTerm.Draw()
	if err != nil {
		log.Println(err)
		panic(err)
	}
loop:
	for {
		switch ev := termbox.PollEvent(); ev.Type {
		case termbox.EventKey:
			switch {
			case ev.Key == termbox.KeyEsc || ev.Ch == 'Q' || ev.Ch == 'q':
				break loop
			case ev.Ch == ' ' || ev.Ch == 'n' || ev.Ch == 'N' || ev.Key == termbox.KeyArrowDown || ev.Key == termbox.KeyPgdn:
				TheTerm.NextPage()
			case ev.Ch == 'p' || ev.Ch == 'P' || ev.Key == termbox.KeyArrowUp || ev.Key == termbox.KeyPgup:
				TheTerm.PrevPage()
			case ev.Ch == 'r' || ev.Ch == 'f' || ev.Ch == 'R' || ev.Ch == 'F' || ev.Key == termbox.KeyArrowRight:
				TheTerm.ScrollRight()
			case ev.Ch == 'l' || ev.Ch == 'b' || ev.Ch == 'L' || ev.Ch == 'B' || ev.Key == termbox.KeyArrowLeft:
				TheTerm.ScrollLeft()
			case ev.Ch == 'a' || ev.Ch == 'A' || ev.Key == termbox.KeyHome:
				TheTerm.Top()
			case ev.Ch == 'e' || ev.Ch == 'E' || ev.Key == termbox.KeyEnd:
				TheTerm.End()
			case ev.Ch == 'w' || ev.Ch == 'W':
				TheTerm.FixRight()
			case ev.Ch == 's' || ev.Ch == 'S':
				TheTerm.FixLeft()
			case ev.Ch == 'd' || ev.Ch == 'D':
				TheTerm.ToggleNames()
			case ev.Ch == 'h' || ev.Ch == 'H':
				TheTerm.Help()
			}
		case termbox.EventResize:
			TheTerm.Draw()
		}
	}
}
