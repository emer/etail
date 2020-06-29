// Copyright (c) 2020, The Emergent Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"
	"image"

	"github.com/goki/ki/ints"
	"github.com/nsf/termbox-go"
)

var MinLines = 5

type Term struct {
	Size      image.Point
	FixCols   int  `desc:"number of fixed (non-scrolling) columns on left"`
	ColSt     int  `desc:"starting column index -- relative to FixCols"`
	RowSt     int  `desc:"starting row index"`
	FileSt    int  `desc:"starting index into files (if too many to display)"`
	NFiles    int  `desc:"number of files to display (if too many to display)"`
	MaxWd     int  `desc:"maximum column width (1/4 of term width)"`
	MaxRows   int  `desc:"max number of rows across all files"`
	ShowFName bool `desc:"if true, print filename"`
	YPer      int  `desc:"number of Y rows per file total: Size.Y / len(TheFiles)"`
	RowsPer   int  `desc:"rows of data per file (subtracting header, filename)"`
}

var TheTerm Term

func (tm *Term) Draw() error {
	err := termbox.Clear(termbox.ColorDefault, termbox.ColorDefault)
	if err != nil {
		return err
	}
	w, h := termbox.Size()
	tm.Size.X = w
	tm.Size.Y = h
	tm.MaxWd = tm.Size.X / 4

	nf := len(TheFiles)
	if nf == 0 {
		return fmt.Errorf("No files")
	}

	tm.YPer = tm.Size.Y / nf
	tm.NFiles = nf

	if tm.YPer < MinLines {
		tm.NFiles = tm.Size.Y / MinLines
		tm.YPer = MinLines
	}
	if tm.NFiles+tm.FileSt > nf {
		tm.FileSt = ints.MaxInt(0, nf-tm.NFiles)
	}

	tm.RowsPer = tm.YPer - 1
	if tm.ShowFName {
		tm.RowsPer--
	}
	sty := 0
	mxrows := 0
	for fi := 0; fi < tm.NFiles; fi++ {
		ffi := tm.FileSt + fi
		if ffi >= nf {
			break
		}
		fl := TheFiles[ffi]
		tm.DrawFile(fl, sty)
		sty += tm.YPer
		mxrows = ints.MaxInt(mxrows, fl.Rows)
	}
	tm.MaxRows = mxrows
	termbox.Flush()
	return nil
}

func (tm *Term) NextPage() error {
	tm.RowSt = ints.MinInt(tm.RowSt+tm.RowsPer, tm.MaxRows-tm.RowsPer)
	tm.RowSt = ints.MaxInt(tm.RowSt, 0)
	return tm.Draw()
}

func (tm *Term) PrevPage() error {
	tm.RowSt = ints.MaxInt(tm.RowSt-tm.RowsPer, 0)
	tm.RowSt = ints.MinInt(tm.RowSt, tm.MaxRows-tm.RowsPer)
	return tm.Draw()
}

func (tm *Term) Top() error {
	tm.RowSt = 0
	return tm.Draw()
}

func (tm *Term) End() error {
	tm.RowSt = tm.MaxRows - tm.RowsPer
	return tm.Draw()
}

func (tm *Term) ScrollRight() error {
	tm.ColSt++ // no obvious max
	return tm.Draw()
}

func (tm *Term) ScrollLeft() error {
	tm.ColSt = ints.MaxInt(tm.ColSt-1, 0)
	return tm.Draw()
}

func (tm *Term) FixRight() error {
	tm.FixCols++ // no obvious max
	return tm.Draw()
}

func (tm *Term) FixLeft() error {
	tm.FixCols = ints.MaxInt(tm.FixCols-1, 0)
	return tm.Draw()
}

func (tm *Term) ToggleNames() error {
	tm.ShowFName = !tm.ShowFName
	return tm.Draw()
}

func (tm *Term) DrawFile(fl *File, sty int) {
	stx := 0
	for ci, hs := range fl.Heads {
		if !(ci < tm.FixCols || ci >= tm.FixCols+tm.ColSt) {
			continue
		}
		my := sty
		if tm.ShowFName {
			tm.DrawString(0, my, fl.FName, tm.Size.X, termbox.AttrReverse, termbox.AttrReverse)
			my++
		}
		wmax := ints.MinInt(fl.Widths[ci], tm.MaxWd)
		tm.DrawString(stx, my, hs, wmax, termbox.AttrReverse, termbox.AttrReverse)
		if ci == tm.FixCols-1 {
			tm.DrawString(stx+wmax+1, my, "|", 1, termbox.AttrReverse, termbox.AttrReverse)
		}
		my++
		for ri := 0; ri < tm.RowsPer; ri++ {
			di := tm.RowSt + ri
			if di >= len(fl.Data) {
				break
			}
			dr := fl.Data[di]
			if ci >= len(dr) {
				break
			}
			ds := dr[ci]
			tm.DrawString(stx, my+ri, ds, wmax, termbox.ColorDefault, termbox.ColorDefault)
			if ci == tm.FixCols-1 {
				tm.DrawString(stx+wmax+1, my+ri, "|", 1, termbox.AttrReverse, termbox.AttrReverse)
			}
		}
		stx += wmax + 1
		if ci == tm.FixCols-1 {
			stx += 2
		}
		if stx >= tm.Size.X {
			break
		}
	}
}

func (tm *Term) DrawStringDef(x, y int, s string) {
	tm.DrawString(x, y, s, tm.Size.X, termbox.ColorDefault, termbox.ColorDefault)
}

func (tm *Term) DrawString(x, y int, s string, maxlen int, fg, bg termbox.Attribute) {
	if y >= tm.Size.Y || y < 0 {
		return
	}
	for i, r := range s {
		if i >= maxlen {
			break
		}
		xp := x + i
		if xp >= tm.Size.X || xp < 0 {
			continue
		}
		termbox.SetCell(xp, y, r, fg, bg)
	}
}
