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

sub HELP_MESSAGE {
  print <<'END-OF-USAGE';
'
Usage: ccnfdump.pl input1.ccnf [input2.ccnf ...]

This program takes a set of input CCNF files, and dumps the
URIs to stdout 
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

#------------------------------------------------------------------------------
# Main
if ($#ARGV+1 <= 0) {
  # No input files 
  HELP_MESSAGE();
}
my $count=0;
foreach (@ARGV) {
  open(CCNFILE, "<:raw", $_) || die "Cannot open $_ file reading\n";
  while (1) {
      my ($numtok, $len, @uri) = ccnf_read_uri(CCNFILE);
      last if ($numtok == 0);
      print "$count $numtok $len " . (join "/", @uri) . "\n";
      $count++;
  }
  close CCNFILE;
  print "Read $count lines\n";
}
