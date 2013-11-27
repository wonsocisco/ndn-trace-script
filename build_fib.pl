#!/usr/bin/perl
################################################################################
#  NDN Trace Script
#  Copyright (c) 2012-2013 by Cisco Systems, Inc.
#  All rights reserved.
#  Written by Ashok Narayanan and Won So
#
#  NDN Trace Script is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  NDN Trace Script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
################################################################################

use File::Basename;
use Getopt::Std;

#------------------------------------------------------------------------------
# Usage
#
sub HELP_MESSAGE {
  print <<'END-OF-USAGE';
'
Usage: build_fib.pl -n <Max number of prefix tokens>
                    { -P [-I] | -p <Number of prefixes to generate> }
		    -H <Histogram distribution of prefixes>
		    -o <Output FIB file>
		    input1.ccnf [input2.ccnf ...]

This program takes a set of input CCNF files, and generates a FIB
from all these files. The FIB is composed of a set of prefixes,
all of which can be found in the inputs. The input URIs are
used to generate a set of unique covering FIB prefixes of all possible
lengths. The user specifies a histogram profile of the target FIB to
be generated, and FIB entries are then selected at random from the 
unique covering sets, in proportion to the histogram of token counts.

The following options are supported. 

 - The maximum length of any FIB prefix (in tokens) is specified using '-n'.
   e.g. "-n 8" specifies all FIB prefixes to have 8 tokens or less.

 - A histogram describing the distribution of number of FIB prefixes with
   different numbers of tokens is specified using -H. This is mandatory
   and the histogram must have the same number of elements as is specified
   in -n. Each element is a number between 1 and 10000, represnting a 
   fraction therein. For example, "-n 4 -H 0,1500,4500,4000" specifies
   all FIB prefixes be 4 tokens or less, and the generated FIB will have 
   a distribution of 0% entries with 1 token, 15% entries with 2 tokens,
   45% entries with 3 tokens, and 40% entries with 4 tokens. All elements
   must add up to exactly 10000. As a convenience, the last element only
   can be specified as -1, and it will automatically be calculated. In 
   the previous example therefore could be written as "-H 0,1500,4500,-1".

 - The number of prefixes to be generated in the FIB. This can be specified 
   in one of two ways:

    - An explicit limit on the number of prefixes using the "-p <num>" option.
      This pool is then divided up in proportion to the histogram fractions,
      and the FIB is built with this divided pool. Note that it is possible
      that the fraction of "-p" pool required for a particular histogram
      bucket may be greater than the number of unique prefixes fitting 
      in that bucket, in the source. In this case, the program will throw
      an error and stop.

    - By specifying "-P" instead of "-p",  the program will automatically
      determine the largest FIB that can be generated from this data set
      according to the histogram profile provided, and it will generate this
      FIB. Note that in this case, one of the token lengths is the bounding
      set, that is to say that at least one of the sets of prefixes generated
      by token length is exactly as big as the proportional share requested
      for that token length by the histogram. In order to guarantee the FIB
      to fully cover the URI inputs, the program will select all the entries
      of that prefix length. This can be overridden with "-I", in which case
      random entries will be selected from all sets and it is possible
      the FIB may not cover all prefixes (though it will cover almost
      all prefixes in most cases). 

 - An output file where a CCNF FIB is written, specified with "-o"

 - A set of input CCNF files with URIs specified at the end of the command line.

Example:

  ./build_fib.pl -n 8 -P -H 0,176,2853,3694,1918,692,328,-1 -o fib.ccnf url1.ccnf url2.ccnf url3.ccnf

This command takes three CCNF URL files named url1.ccnf, url2.ccnf and url3.ccnf
and builds a single combined FIB into fib.ccnf. All prefixes in the FIB are
eight tokens or less. The histogram of token distribution is specified, 
with 0% having 1 token, 1.76% with 2 tokens, 28.53% with 3 tokens, and so on
until 3.28% with 7 tokens and whatever remains goes into the 8-token set.
The maximum number of FIB entries will be computed by the program to 
generate the largest FIB that fits both the target histogram specified
and the URL sets.

Here is the output of that command:

  Automatically calculating last histogram element
  Prefix histogram: 0 176 2853 3694 1918 692 328 339
  Reading url1.ccnf
  10000 ... 
  <snip>
  230000 ...
  Computed number of prefixes: 74468
  Prefix target counts: 0 1310 21245 27508 14282 5153 2442 2524
  1 token(s): 621 to 0 final 0
  2 token(s): 12863 to 176 final 1310
  3 token(s): 21246 to 2853 final 21245
  4 token(s): 37299 to 3694 final 27508
  5 token(s): 65071 to 1918 final 14282
  6 token(s): 61451 to 692 final 5153
  7 token(s): 40396 to 328 final 2442
  8 token(s): 26946 to 339 final 2524
  Wrote 0 prefixes of length 1
  Wrote 1310 prefixes of length 2
  Wrote 21245 prefixes of length 3
  Wrote 27508 prefixes of length 4
  Wrote 14282 prefixes of length 5
  Wrote 5153 prefixes of length 6
  Wrote 2442 prefixes of length 7
  Wrote 2524 prefixes of length 8
  Wrote 74464 prefixes total

'

END-OF-USAGE

exit 1;
}

#------------------------------------------------------------------------------
# ccnf_read_uri
#
# Takes a filehandle as a single argument, and reads in a single CCNF URI
# from that file. The function returns an array of this type:
#
#  (number-of-tokens, total-length-in-bytes, (array-of-uri-components))
#
# number-of-tokens is returned as zero if a header could not be read
#
# See ccnfdump.pl for an example of how to use this function
#
sub ccnf_read_uri {
    my $numtok = 0, $len = 0, $hdr, $buf;
    my @uri;

    # Try to read the 3-byte header 
    if (read CCNFILE, $hdr, 3) {
	($numtok, $len) = unpack('CS>', $hdr);
	read CCNFILE, $buf, $len;

	$offset = 0;
	while ($offset < $len) {
	    $complen = unpack("C", substr $buf, $offset);
	    if ( $complen > 127) {
		$complen = unpack("S>", substr $buf, $offset);
		$complen &= 0x7ff;
		$offset++;
	    }
	    push @uri, substr $buf, $offset+1, $complen;
	    $offset += $complen + 1;
	}
    }
    return ($numtok, $len, @uri);
}

# ------------------------------------------------------------------------------
# ccnf_pack_uri
#
# Takes an array of components and returns a packed CCNF URI
#
sub ccnf_pack_uri {
    my $line = "", $totlength ;
    my $totlength = 0;
    my $numcomponents = (scalar @_);
    #print "\n||$numcomponents||$totlength||";
    foreach (@_) {
      my $clen = length;
      if ($clen > 127) {
	$lcomp = pack ( "S>A*", (32768 | $clen), $_);
	$totlength += $clen + 2;
	$line.= $lcomp;
	#print "|>" . length . "|" . $_;
      } elsif ($clen > 0) {
	$lcomp = pack ( "CA*", $clen, $_);
	$totlength += $clen+1;
	$line .= $lcomp;
	#print "|" . length . "|" . $_;
      }
    }
    return pack ( "CS>A*", $numcomponents, $totlength, $line);
}

#------------------------------------------------------------------------------
# Main
getopt("hpnNHo", \%opts);

if ( scalar keys %opts <= 0) {
  HELP_MESSAGE();
}

my $MIN_PREFIX = 1;
my $MAX_PREFIX = 8;
my @PREFIXHIST;


#if (exists $opts{'N'}) {
#  $MIN_PREFIX=$opts{'N'};
#}

# Check for required parameters
if (!exists $opts{'n'} ||
    !exists $opts{'H'} ||
    (!exists $opts{'p'} && !exists $opts{'P'} ) ||
    !exists $opts{'o'}) {
  HELP_MESSAGE();
}

$MAX_PREFIX=$opts{'n'};
$OUTFILE=$opts{'o'};
if (exists $opts{'p'}) {
  $NUM_ENTRIES=$opts{'p'};
} else {
  $NUM_ENTRIES = 10000;
}
@PREFIXHIST=split (',', $opts{'H'});

# Check if we have histogram numbers 
if ($#PREFIXHIST != $MAX_PREFIX - $MIN_PREFIX) {
  print "ERROR: Incorrect number of prefix histogram entries\n";
  print "Min prefix: $MIN_PREFIX. Max prefix: $MAX_PREFIX. Prefix Hist: " . join(',', @PREFIXHIST) . "\n";
  HELP_MESSAGE();
}

my $histsum = 0;
map { $histsum += $_ } @PREFIXHIST;

if ($PREFIXHIST[$#PREFIXHIST] == -1) {
  # automatically calculate last element
  print "Automatically calculating last histogram element\n";
  $PREFIXHIST[$#PREFIXHIST] = (10000-$histsum-1);
} else {
  # check if histogram is complete
  if ($histsum != 10000) {
    print "ERROR: Prefix histogram set doesn't sum to 10000.\n";
    print "Min prefix: $MIN_PREFIX. Max prefix: $MAX_PREFIX. Prefix Hist: " . join(',', @PREFIXHIST) . "\n";
    HELP_MESSAGE();
  }
}

# Push zeros onto front if required
foreach (2..$MIN_PREFIX) {
    unshift @PREFIXHIST, 0;
}
print "Prefix histogram: " . join(" ", @PREFIXHIST) . "\n";

@PFXTARGET_COUNTS = map { int (($NUM_ENTRIES * $_ ) / 10000) } @PREFIXHIST;
print "Prefix target counts: " . join(" ", @PFXTARGET_COUNTS) . "\n";

if ($#ARGV+1 <= 0) {
  # No input files 
  HELP_MESSAGE();
}

my $idx = 0;
my @uri_array;
my %FIB = ({});
my @FIBIDX = (());
my @FIBCNT = ();
my $FIBSUM = 0;

# Read in all the files 
foreach (@ARGV) {
    print "Reading $_\n";
    open(CCNFILE, "<:raw", $_) || die "Cannot open $_ file reading\n";
    while (1) {
	# Grab a URI
	my ($numtok, $len, @uri) = ccnf_read_uri(CCNFILE);
	last if ($numtok == 0);

	# Put it into main list 
	push @uri_array, [ @uri ];
	#print join "/", @uri;
	#print "\n";

	# Put indexes into all the correct places
	foreach ($MIN_PREFIX .. $MAX_PREFIX) {
	    last if $_ > $numtok;
	    $pfx = join('/', @uri[0 .. $_-1]);
	    #print "$_ $pfx\n";
	    if (! exists $FIB[$_]{$pfx}) {
		$FIB[$_]{$pfx} = $idx;
		push @{ $FIBIDX[$_] }, $idx;
		$FIBCNT[$_] ++;
		$FIBSUM ++;
	    }
	}
	$idx ++;
	print "$idx ... \n" unless $idx % 10000;
    }
}

if (exists $opts{'P'}) {
  # Automatically set number of prefixes to max
  $NUM_ENTRIES = 100000000;
  foreach ($MIN_PREFIX .. $MAX_PREFIX) {
    if ($PREFIXHIST[$_-$MIN_PREFIX] > 0) {
      my $tm = ($FIBCNT[$_] * 10000)/$PREFIXHIST[$_-$MIN_PREFIX];
      if ($NUM_ENTRIES > $tm) { $NUM_ENTRIES = int $tm; $BOUNDING_PREFIX_LEN = $_;}
    }
  }
  @PFXTARGET_COUNTS = map { int (($NUM_ENTRIES * $_ ) / 10000) } @PREFIXHIST;
  print "Computed number of prefixes: " . $NUM_ENTRIES . "\n";
  print "Prefix target counts: " . join(" ", @PFXTARGET_COUNTS) . "\n";
}

# Check if we have enough prefixes of each length
foreach ($MIN_PREFIX .. $MAX_PREFIX) {
    if ($PFXTARGET_COUNTS[$_-$MIN_PREFIX] > $FIBCNT[$_]) {
	print "ERROR: Histogram requires $PFXTARGET_COUNTS[$_-$MIN_PREFIX] entries of $_ tokens, but only $FIBCNT[$_] available\n";
	print "Required prefix counts: " . join(" ", @PFXTARGET_COUNTS) . "\n";
	print "Available prefix counts: " . join(" ", @FIBCNT) . "\n";
	exit 1;
    }
}

foreach ($MIN_PREFIX .. $MAX_PREFIX) {
    print "$_ token(s): " . $FIBCNT[$_] . " to " . $PREFIXHIST[$_-$MIN_PREFIX] . " final " . $PFXTARGET_COUNTS[$_-$MIN_PREFIX] . "\n";
#    print join "\n", (sort keys %{$FIB[$_]}) unless $_ > 2;
#    print "----------------------------------------------------------------------\n";
}

# Build the final FIB
$z = 0;
open(FIBFILE, ">:raw", $OUTFILE) || die "Cannot open $OUTFILE for writing\n";
foreach $pfx ($MIN_PREFIX .. $MAX_PREFIX) {
    $y = 0;
    my $x = 0;

    my %rvals = {}; # stores the random values
    srand(0); # always generates the same FIB

    foreach (1 .. $PFXTARGET_COUNTS[$pfx-$MIN_PREFIX]) {
      if (exists $opts{'P'} && 
          (! exists $opts{'I'}) && 
          $pfx == $BOUNDING_PREFIX_LEN) {
	$x = $_;
      } else {
          while (TRUE) {
              $x = int(rand($FIBCNT[$pfx]));
              # random could choose the same value repeately
              if (!exists $rvals{$x}) {
                  $rvals{$x} = 1;
                  last;
              }
              # otherewise, keep do random...
          }
      }
      print FIBFILE ccnf_pack_uri(@{$uri_array[$FIBIDX[$pfx][$x]]}[0..$pfx-1]);
      $z++; $y++;
    }
    print "Wrote $y prefixes of length $pfx\n";
}
close(FIBFILE);
print "Wrote $z prefixes total\n";
