// Copyright (c) 2020, The Emergent Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"bufio"
	"os"
	"strings"

	"github.com/goki/ki/ints"
)

type File struct {
	FName  string
	Rows   int `desc:"rows of data == len(Data)"`
	Widths []int
	Heads  []string
	Data   [][]string
}

type Files []*File

var TheFiles Files

func (fl *File) Open(fname string) error {
	fl.FName = fname
	return fl.Read()
}

func (fl *File) Read() error {
	f, err := os.Open(fl.FName)
	if err != nil {
		return err
	}
	defer f.Close()

	scan := bufio.NewScanner(f)
	ln := 0
	for scan.Scan() {
		s := string(scan.Bytes())
		fd := strings.Fields(s)
		if ln == 0 {
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

func (fl *Files) Open(fnms []string) {
	for _, fn := range fnms {
		f := &File{}
		err := f.Open(fn)
		if err == nil {
			*fl = append(*fl, f)
		}
	}
}
