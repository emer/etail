# etail: monitor log files in the terminal

[![Go Report Card](https://goreportcard.com/badge/github.com/emer/etail)](https://goreportcard.com/report/github.com/emer/etail)
[![GoDoc](https://godoc.org/github.com/emer/emergent?status.svg)](https://godoc.org/github.com/emer/etail)

`etail` is a `tail` command for looking at .csv / .tsv log / data files in a terminal window.

This is a Go rewrite of the `pdptail` command written in perl, dating back to the PDP++ era.

# Install

This should install into your $GOPATH/bin dir:

```bash
$ go get github.com/emer/etail
```

# Run

Just pass files as args, e.g., on the test files in this dir:

```bash
$ etail RA25*
```

# Keys

This is shown when you press `h` in the app:

| Key(s)  | Function      |
| ------- | ------------------------------------------------------ |
| spc,n   | page down                                                     |
| p       | page up                                                       |
| f       | scroll right-hand panel to the right                          |
| b       | scroll right-hand panel to the left                           |
| w       | widen the left-hand panel of columns                          |
| s       | shrink the left-hand panel of columns                         |
| t       | toggle tail-mode (auto updating as file grows) on/off         |
| a       | jump to top                                                   |
| e       | jump to end                                                   |
| v       | rotate down through the list of files (if not all displayed)  |
| u       | rotate up through the list of files (if not all displayed)    |
| m       | more minimum lines per file -- increase amount shown of each file |
| l       | less minimum lines per file -- decrease amount shown of each file |
| d       | toggle display of file names                                  |
| c       | toggle display of column numbers instead of names             |
| q       | quit                                                          |

