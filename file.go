// Copyright (c) 2020, The Emergent Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"bufio"
	"os"
	"strings"
	"time"

	"github.com/goki/ki/ints"
)

// File represents one opened file -- all data is read in and maintained here
type File struct {
	FName   string     `desc:"file name (either in same dir or include path)"`
	ModTime time.Time  `desc:"mod time of file when last read"`
	Commas  bool       `desc:"delim is commas, not whitespace"`
	Rows    int        `desc:"rows of data == len(Data)"`
	Widths  []int      `desc:"width of each column: resized to fit widest element"`
	Heads   []string   `desc:"headers"`
	Data    [][]string `desc:"data -- rows 1..end"`
}

// Files is a slice of open files
type Files []*File

// TheFiles are the set of open files
var TheFiles Files

// Open opens file, reads it
func (fl *File) Open(fname string) error {
	fl.FName = fname
	return fl.Read()
}

// CheckUpdate checks if file has been modified -- returns true if so
func (fl *File) CheckUpdate() bool {
	st, err := os.Stat(fl.FName)
	if err != nil {
		return false
	}
	return st.ModTime().After(fl.ModTime)
}

// Read reads data from file
func (fl *File) Read() error {
	st, err := os.Stat(fl.FName)
	if err != nil {
		return err
	}
	fl.ModTime = st.ModTime()
	f, err := os.Open(fl.FName)
	if err != nil {
		return err
	}
	defer f.Close()

	if fl.Data != nil {
		fl.Data = fl.Data[:0]
	}

	scan := bufio.NewScanner(f)
	ln := 0
	for scan.Scan() {
		s := string(scan.Bytes())
		var fd []string
		if fl.Commas {
			fd = strings.Split(s, ",")
		} else {
			fd = strings.Fields(s)
		}
		if ln == 0 {
			if len(fd) == 0 || strings.Count(s, ",") > strings.Count(s, "\t") {
				fl.Commas = true
				fd = strings.Split(s, ",")
			}
			fl.Heads = fd
			fl.Widths = make([]int, len(fl.Heads))
			fl.FitWidths(fd)
			ln++
			continue
		}
		fl.Data = append(fl.Data, fd)
		fl.FitWidths(fd)
		ln++
	}
	fl.Rows = ln - 1 // skip header
	return err
}

// FitWidths expands widths given current set of fields
func (fl *File) FitWidths(fd []string) {
	nw := len(fl.Widths)
	for i, f := range fd {
		if i >= nw {
			break
		}
		w := ints.MaxInt(fl.Widths[i], len(f))
		fl.Widths[i] = w
	}
}

/////////////////////////////////////////////////////////////////
// Files

// Open opens all files
func (fl *Files) Open(fnms []string) {
	for _, fn := range fnms {
		f := &File{}
		err := f.Open(fn)
		if err == nil {
			*fl = append(*fl, f)
		}
	}
}

// CheckUpdates check for any updated files, re-read if so -- returns true if so
func (fl *Files) CheckUpdates() bool {
	got := false
	for _, f := range *fl {
		if f.CheckUpdate() {
			f.Read()
			got = true
		}
	}
	return got
}
