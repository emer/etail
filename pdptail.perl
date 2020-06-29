#!/usr/bin/perl

if(scalar(@ARGV) < 1) {
    print("Usage: pdptail logfile...\n");
    print("\n");
    print("Displays log file(s) from the pdp++ software with the\n");
    print("header information always at the top, and with two\n");
    print("'panes' of data, the left side always showing the\n");
    print("process counter variables, and the right showing stat\n");
    print("results, etc, which can be scrolled interactively to display\n");
    print("very large amounts of data.\n");
    print("\n");
    print("In tail mode (default) it will automatically follow the file(s)\n");
    print("as new lines are entered, but this can be toggled for viewing\n");
    print("other parts of the file.\n");
    print("\n");
    print("Multiple logs can be viewed (and tailed) at the same time.\n");
    print("\n");
    print("The latest version of this program is available\n");
    print("from: http://psych.colorado.edu/PDP++/pdptail.html\n");
    exit(0);
}

use Curses;
use POSIX;

initscr();
noecho(); 

# separation between columns
$colsep = 1;
# initial state of the tail mode (follow end of file)
$tail_mode = 1;
# sleep time (10ths of a second)
$sleep_time = 1;
# min number of lines per log
$min_lines = 5;
# whether to display file names or not
$disp_fnames = 0;
# whether to display column numbers instead of names
$disp_col_nos = 0;

halfdelay($sleep_time); # wait for char input 

@fnames = @ARGV;

# file handles
@files[$n_files];

$n_files = scalar(@fnames);
$disp_files = $n_files;

# file indicies for each display panel
@disp_fidx[$disp_files] = ();

@headlns[$n_files] = 1;			# no of lines of header before data
@n_fields[$n_files] = 10;
# total lines avail for displaying data
$datalns = $LINES-1;
# lines displayed per file
$displns = $datalns;
$lastln = $LINES-1;

# number of views of columns (ranges of cols to view)
$n_views = 2;

# start and end of each view
@st_field[$n_files] = ();
@ed_field[$n_files] = ();

# widths of the different columns
@widths[$n_files] = ();
# seek positions for each line in the file
@filepos[$n_files] = ();

# total number of lines in file
@n_lines[$n_files] = ();
# what line of the file are we currently viewing?
@cur_ln[$n_files] = ();

# startrow, cols per file
@st_row[$n_files] = 0;
@ed_row[$n_files] = 0;

# get all the file properties: max_fields, widths, etc
# header = the last line before the data starts, indicated by _D:
sub getFileProps {
    my $fnm = $_[0];
    my $fidx= $_[1];
    my($lnstr, @tmpflds, $i, $lstpos, $dataln);

    open(FILE, $fnm);

    $headlns[$fidx] = 0;
    $lstpos = tell(FILE);

    my $pdp_hdr = 0;

    while ($lnstr = <FILE>) {
	@tmpflds = split /\s+/, $lnstr;
	if($tmpflds[0] eq "_H:") {
	    # _H: = pdp++ header line; there can be multiple at the start..
	    $headers[$fidx] = [ @tmpflds ];
	    $headlns[$fidx]++;
	    $pdp_hdr = 1;
	}
	elsif($tmpflds[0] eq "_D:") {
	    # _D: = pdp++ data line -- go with what we got already for headers
	    $filepos[$fidx][0] = $lstpos;
	    last;
	}
	elsif(scalar( @{ [@tmpflds] }) <= 1) {
	    next;
	}
	else {
	    # non-pdp++ data file, just take the 1st line as a header
	    $headers[$fidx] = [ @tmpflds ];
	    $headlns[$fidx]++;
	    $filepos[$fidx][0] = tell(FILE);
	    last;
	}
	$lstpos = tell(FILE);
    }

    $n_fields[$fidx] = scalar( @{ $headers[$fidx] }) + 1;

    addstr($lastln-1,0,$n_fields[$fidx]);
    refresh();

    @widths[$fidx] = ();		# clear it out

    my $end_fld = $n_fields[$fidx];
    my $col = 0;
    for($i=1; $i<$n_fields[$fidx]; $i++) {
 	$widths[$fidx][$i] = length($headers[$fidx][$i]);
 	$col += $widths[$fidx][$i];
 	if($col > $COLS) {
 	    $end_fld = $i-1;
 	}
    }

    if($n_fields[$fidx] < 10) {
	$st_field[$fidx][0] = $pdp_hdr;	# if pdp, skip 1st cols
	$ed_field[$fidx][0] = $end_fld / 2;
	$st_field[$fidx][1] = ($end_fld / 2) +1;
	$ed_field[$fidx][1] = $end_fld - 1;
    }
    else {
	$st_field[$fidx][0] = $pdp_hdr;	
	$ed_field[$fidx][0] = 5;
	$st_field[$fidx][1] = 6;
	$ed_field[$fidx][1] = $end_fld-1;
    }

    seek(FILE, $filepos[$fidx][0], 0);	# go back to first data item

    addstr($lastln,0,"getting file size, line:");
    refresh();
    $lstpos = tell(FILE);
    $dataln = 0;
    while ($lnstr = <FILE>) {
	addstr($lastln,25,"$dataln");
	refresh();
	@tmpflds = split /\s+/, $lnstr;
	$filepos[$fidx][$dataln++] = $lstpos;
	for($i=0; $i<$n_fields[$fidx]; $i++) {
	    my $len = length($tmpflds[$i]);
	    if($len > $widths[$fidx][$i]) {
		$widths[$fidx][$i] = $len;
	    }
	}
	$lstpos = tell(FILE);
    }
    
    $n_lines[$fidx] = $dataln;
    $cur_ln[$fidx] = 0;

    close(FILE);
}

sub getDispLines {
    $disp_files = $n_files;
    $displns = floor($datalns / $n_files) - 1;
    if($disp_fnames) {
	$displns--;
    }
    if($displns < $min_lines) {
	my $act_lns = $min_lines+1;
	if($disp_fnames) { $act_lns++; }
	$disp_files = floor($datalns / $act_lns);
	$displns = $min_lines;
    }

    my $i=0;
    my $row = 0;
    for($i=0; $i<$disp_files; $i++) {
	$st_row[$i] = $row;
	$ed_row[$i] = $row + $displns;
	$row += $displns + 1;
	if($disp_fnames) {
	    $row++;
	}
	$disp_fidx[$i] = $i;	# which file is being displayed in this place
    }
}

# prints out the header, for given display index
sub printHeader {
    my $disp_idx= $_[0];
    my($col, $nxtcol, $fld, $vw);

    my $fidx = $disp_fidx[$disp_idx];

    my $row = $st_row[$disp_idx];
    attron(A_REVERSE);
    if($disp_fnames) {
	addstr($row++, $col, "$fnames[$fidx]");
    }
    $col = 0;
    for($vw=0;$vw < $n_views; $vw++) {
	$fld = $st_field[$fidx][$vw];
	while($fld <= $ed_field[$fidx][$vw]) {
	    $nxtcol = $col + $widths[$fidx][$fld] + $colsep;
	    if($nxtcol > $COLS) { 
		$ed_field[$fidx][$vw] = $fld-1;
		last;
	    }
	    if($disp_col_nos) {
		addstr($row, $col, "$fld");
	    }
	    else {
		addstr($row, $col, "$headers[$fidx][$fld]");
	    }
	    $col = $nxtcol;
	    $fld++;
	}
	if($col > $COLS) { last; }
	if($vw < $n_views-1) {
	    addch($row, $col, ACS_VLINE);
	    $col++;
	}
    }
    attroff(A_REVERSE);
    refresh();
}

# takes the line string, line to start printing on
sub printLine {
    my $disp_idx= $_[0];
    my $lnstr = $_[1];
    my $row = $_[2] + 1;
    my(@fields, $vw, $fld, $col, $nxtcol);

    my $fidx = $disp_fidx[$disp_idx];

    if($disp_fnames) {
	$row++;
    }

    # get the individual fields worth of data
    @fields = split /\s+/, $lnstr;

    $col = 0;
    for($vw=0;$vw < $n_views; $vw++) {
	$fld = $st_field[$fidx][$vw];
	while($fld <= $ed_field[$fidx][$vw]) {
	    $nxtcol = $col + $widths[$fidx][$fld] + $colsep;
	    if($nxtcol > $COLS) { 
		last;
	    }
	    addstr($row, $col, "$fields[$fld]");
	    $col = $nxtcol;
	    $fld++;
	}
	if($col > $COLS) { last; }
	if($vw < $n_views-1) {
	    addch($row, $col, ACS_VLINE);
	    $col++;
	}
    }
    refresh();
}

# fill the current screen with data from the file, given starting line
sub fillScreen {
    for($disp_idx=0; $disp_idx < $disp_files; $disp_idx++) {
	my $fidx = $disp_fidx[$disp_idx];
	my $st_ln = $cur_ln[$fidx];

	&printHeader($disp_idx);

	open(FILE, $fnames[$fidx]);
	seek(FILE, $filepos[$fidx][$st_ln], 0);

	for($ln = 0; $ln < $displns; $ln++) {
	    if($st_ln + $ln >= $n_lines[$fidx]) { last; }
	    my $row = $st_row[$disp_idx] + $ln;
	    $lnstr = <FILE>;
	    &printLine($disp_idx, $lnstr, $row);
	}
	close(FILE);
    }
}

my $fidx;
for($fidx=0; $fidx < $n_files; $fidx++) {
    &getFileProps($fnames[$fidx], $fidx);
}

&getDispLines();

my $update = 1;
while(1) {

    if($update) {
	clear();
	&fillScreen();
	$update = 0;
	addstr($lastln, 10, "h = help [spc,n,p,r,f,l,b,w,s,t,a,e,v,u,c,q]");
	attron(A_REVERSE);
	if($tail_mode) {
	    addstr($lastln, 0, "T");
	}
	else {
	    addstr($lastln, 0, "F");
	}
	attroff(A_REVERSE);
	refresh();
    }
    $resp = getch();
    
    if($tail_mode) {
	for($fidx=0; $fidx < $n_files; $fidx++) {
	    open(FILE, $fnames[$fidx]);
	    # do the tail thing
	    seek(FILE, $filepos[$fidx][$n_lines[$fidx]-1], 0);
	    my $lnstr = <FILE>;
	    $lstpos = tell(FILE);
	    while(!eof(FILE)) {
		$n_lines[$fidx]++;
		$filepos[$fidx][$n_lines[$fidx]-1] = $lstpos;
		$cur_ln[$fidx] = ($n_lines[$fidx] - $displns);
		if($cur_ln[$fidx] < 0) {
		    $cur_ln[$fidx] = 0;
		}
		$lnstr = <FILE>;
		$lstpos = tell(FILE);
		$update = 1;
	    }
	    close(FILE);
	}
    }

    if($resp == ERR) {
	# timeout, do nothing..
    }
    elsif($resp eq 'p') {
	for($fidx=0; $fidx < $n_files; $fidx++) {
	    $cur_ln[$fidx] -= $displns;
	    if($cur_ln[$fidx] < 0) { $cur_ln[$fidx] = 0; }
	}
	$update = 1;
    }
    elsif($resp eq ' ' || $resp eq 'n') {
	for($fidx=0; $fidx < $n_files; $fidx++) {
	    $cur_ln[$fidx] += $displns;
	    if($cur_ln[$fidx] >= ($n_lines[$fidx] - $displns)) {
		$cur_ln[$fidx] = ($n_lines[$fidx] - $displns);
	    }
	    if($cur_ln[$fidx] < 0) {
		$cur_ln[$fidx] = 0;
	    }
	}
	$update = 1;
    }
    elsif ($resp eq 'r' || $resp eq 'f') {
	for($fidx=0; $fidx < $n_files; $fidx++) {
	    if($ed_field[$fidx][1] < $n_fields[$fidx]-1) {
		$st_field[$fidx][1]++;
		$ed_field[$fidx][1]+=2;
	    }
	}
	$update = 1;
    }
    elsif ($resp eq 'l' || $resp eq 'b') {
	for($fidx=0; $fidx < $n_files; $fidx++) {
	    if($st_field[$fidx][1] > $ed_field[$fidx][0]+1) {
		$st_field[$fidx][1]--;
	    }
	}
	$update = 1;
    }
    elsif ($resp eq 'w') {
	for($fidx=0; $fidx < $n_files; $fidx++) {
	    if($ed_field[$fidx][0] < $n_fields[$fidx]-2) {
		$ed_field[$fidx][0]++;
		if($st_field[$fidx][1] <= $ed_field[$fidx][0]) {
		    $st_field[$fidx][1] = $ed_field[$fidx][0]+1;
		    if($ed_field[$fidx][1] <= $st_field[$fidx][1]) {
			$ed_field[$fidx][1] = $st_field[$fidx][1]+1;
		    }
		}
	    }
	}
	$update = 1;
    }
    elsif ($resp eq 's') {
	for($fidx=0; $fidx < $n_files; $fidx++) {
	    if($ed_field[$fidx][0] > 2) {
		$ed_field[$fidx][0]--;
		$st_field[$fidx][1]--;
	    }
	}
	$update = 1;
    }
    elsif ($resp eq 't') {
	if($tail_mode) {
	    $tail_mode = 0;
	    # no need to do the update thing
	    cbreak(); 
	}
	else {
	    $tail_mode = 1;
	    halfdelay($sleep_time); # wait for char input 
	}
	$update = 1;
    }
    elsif ($resp eq 'a') {
	for($fidx=0; $fidx < $n_files; $fidx++) {
	    $cur_ln[$fidx] = 0;
	}
	$update = 1;
    }
    elsif ($resp eq 'e') {
	for($fidx=0; $fidx < $n_files; $fidx++) {
	    $cur_ln[$fidx] = ($n_lines[$fidx] - $displns);
	    if($cur_ln[$fidx] < 0) {
		$cur_ln[$fidx] = 0;
	    }
	}
	$update = 1;
    }
    elsif ($resp eq 'v') {
	if($disp_files < $n_files) {
	    if($disp_fidx[$disp_files-1] < $n_files-1) {
		for($disp_idx=0; $disp_idx < $disp_files; $disp_idx++) {
		    $disp_fidx[$disp_idx]++;
		}
	    }
	}
	$update = 1;
    }
    elsif ($resp eq 'u') {
	if($disp_files < $n_files) {
	    if($disp_fidx[0] > 0) {
		for($disp_idx=0; $disp_idx < $disp_files; $disp_idx++) {
		    $disp_fidx[$disp_idx]--;
		}
	    }
	}
	$update = 1;
    }
    elsif ($resp eq 'd') {
	if($disp_fnames) {
	    $disp_fnames = 0;
	}
	else {
	    $disp_fnames = 1;
	}
	&getDispLines();
	$update = 1;
    }
    elsif ($resp eq 'c') {
	if($disp_col_nos) {
	    $disp_col_nos = 0;
	}
	else {
	    $disp_col_nos = 1;
	}
	$update = 1;
    }
    elsif ($resp eq 'h') {
	clear();
	my $ln = 0;
	addstr($ln++, 0, "Key(s)  Function");
	addstr($ln++, 0, "--------------------------------------------------------------");
	addstr($ln++, 0, "spc,n   page down");
	addstr($ln++, 0, "p       page up");
	addstr($ln++, 0, "r,f     scroll right-hand panel to the right");
	addstr($ln++, 0, "l,b     scroll right-hand panel to the left");
	addstr($ln++, 0, "w       widen the left-hand panel of columns");
	addstr($ln++, 0, "s       shrink the left-hand panel of columns");
	addstr($ln++, 0, "t       toggle tail-mode (auto updating as file grows) on/off");
	addstr($ln++, 0, "a       jump to top");
	addstr($ln++, 0, "e       jump to end");
	addstr($ln++, 0, "v       rotate down through the list of files (if not all displayed)");
	addstr($ln++, 0, "u       rotate up through the list of files (if not all displayed)");
	addstr($ln++, 0, "d       toggle display of file names");
	addstr($ln++, 0, "c       toggle display of column numbers instead of names");
	addstr($ln++, 0, "q       quit");
	$ln++;
	addstr($ln++, 0, "        <press any key to continue>");
	refresh();
	
	cbreak(); 
	my $wait = getch();
	if($tail_mode) {
	    halfdelay($sleep_time); # wait for char input 
	}
	$update = 1;
    }
    elsif ($resp eq 'q') {
	last;
    }
}

endwin();
