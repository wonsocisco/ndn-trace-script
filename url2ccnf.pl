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

# Build histograms out of the URL lists if required

#cat $URLS  | sed -e 's/\?.*/\//' | tr -dc '\.\/\n' | sed -e 's/\/\.*/\//g'  | while read PK; do echo ${#PK} $PK; done | cut -f1 -d' ' | sort -n | uniq -c > $URLHIST


my %PLENLIST, %PLLENLIST;
my %HIST, %LHIST;

if ($#ARGV+1 <= 0) {
  print <<'END-OF-USAGE';

Usage: url2ccnf.pl [-f] <uri-file> [<uri-file> ...]

This program takes one or more files with URIs or URLs and 
does the following operations:

1) Normalize URLs into CCN-style components
2) Write URLs into CCNF binary format file
3) Generate histogram based on component count
4) Join all component counts of all files

URL normalization rules are as follows:
 - Discard http:// and https:// prefix
 - Convert '.'-separated domain name preceding the first '/' into multiple 
   components in reverse order (e.g. google.com/abc --> com|google|abc)
 - Split all '/' separated components after the domain name into
   separate components (e.g. cisco.com/abc.de/fgh --> com|cisco|abc.de|fgh)
 - Anything after the first '?' is considered a query string and goes as 
   one component (e.g. cisco.com/ab?google.com --> com|cisco|ab?google.com)
(The same rules are used for the following papers: Won So, Ashok Narayanan, and David Oran, Named data networking on a router: fast and DoS-resistant forwarding with hash tables, In Proceedings of the 2013 ACM/IEEE Nineth Symposium on Architectures for Networking and Communications Systems, Oct. 2013.)

CCNF binary format is defined as follows:
(Note that this is an example of a simple and compact name format that can be used, not the actual format used in NDN/CCN communities. A similar format appears at the paper, Networking Named Content by Van Jacobson et al.) 

  Tokenized-Name := <Num-Components> <Name-Length> <Component> [<Component ...]

  Num-Tokens := {1 byte, Number of components in name}

  Name-Length := {2 bytes, cumulative length of all components in bytes, not 
                  including the <Num-Tokens> or <Name-Length> fields }

  Component := {Component-length} {Component bytes...}

  Component-Length := {1- or 2 bytes, encoded length of component string not 
                       including this field}

The Component-Length field is encoded as follows:
  * If the top bit of the first byte is 0 (i.e. <128), the lower 7 bits 
    encode the total length of that component (used for components up to 
    127 bytes long)
  * If the top 4 bit of the first byte are 1000, the component length 
    is 12 bits long, with the lower 4 bits of the first byte and all 
    8 bits of the second byte encoding the component length. The lower 
    4 bits of the first byte form the 4 most significant bits of the 
    composed length.
  * Top 4 bit values of 1001-1111 are currently reserved for 
    special-purpose components as yet undefined

Here are some examples of CCNF binary format:


com/google

+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
+ 02 | 00 | 0B | 03 |  c |  o |  m | 06 |  g |  o |  o |  g |  l |  e |
+----+----+----+----+----+----+----+----+----+----+----+----+----+----+



org/ashokn/mail/data

+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
+ 04 | 00 | 16 | 03 |  o |  r |  g | 06 |  a |  s |  h |  o |  k |  n | 04 |  m |
+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
+  a |  i |  l | 04 |  d |  a |  t |  a |
+----+----+----+----+----+----+----+----+


com/cisco/user/ashokn/mail/key/<150-byte key locator>

+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
+ 06 | 00 | B6 | 03 |  c |  o |  m | 05 |  c |  i |  s |  c |  o | 04 |  u |  s |
+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
+  e |  r | 06 |  a |  s |  h |  o |  k |  n | 04 |  m |  a |  i |  l | 03 |  k |
+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
+  e |  y | 80 | 96 |  150 bytes of key locator...                              |
+                       ......                                                  |
+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+



CCNF binary format is written individually for each file. For example, 
if the program is run as follows:

    url2ccnf.pl test1.url test2.url

the program will generate test1.url.ccnf with all the URLs from test1.url
encoded in CCNF binary format, and similary test2.url.ccnf. The CCNF file
is simply a binary stream of all the URLs written contiguously. There are
no delimiters or padding/alignment bytes written to the file.

The program will also generate test1.url.hist which is a histogram of
all URLs read from test1, ordered by the number of components in the name.
This file has a simple format, each line contains:

   <Number-of-components> <Number-of-URIs-with-that-many-components>

Lines with 0 components are omitted. Here is an example:

  2 6003
  3 5900
  4 5986
  5 5934
  6 6024

Note that if the .hist and .ccnf files already exist and are newer than
the input file, the re-generation of these files is skipped and the program
will read in the .hist file. This can be overridden with the -f option,
which will force re-generation of these files.

Finally, the program outputs to stdout, a CSV table of all the
histograms, joined. This table has a row for the union of all
component counts in all files, with '0' filled in for columns
which do not have any URIs with that many components. This CSV
file can be used to gain modeling information about the tokens.

END-OF-USAGE

exit 1;
}

# ------------------------------------------------------------------------------
# ccnf_pack_uri
#
# Takes an array of components and returns a packed CCNF URI
#
sub ccnf_pack_uri {
    my $line = "", $totlength ;
    my $totlength = (length (join " ", @ccncomponents)) + 1;
    my $numcomponents = (scalar @_);
    foreach (@_) {
	if (length > 127) {
	    $line .= pack ( "S>A*", (32768 | length), $_);
	    $totlength ++;
	    #if (length ($urlquery) >= 0) 
	    # { print "|>" . length . "|" . $_; }
	} elsif (length > 0) {
	    $line .= pack ( "CA*", length, $_);
	    #if (length ($urlquery) >= 0) 
	    # { print "|" . length . "|" . $_; }
	}
    }
    return pack ( "CS>A*", $numcomponents, $totlength, $line);
}

# ------------------------------------------------------------------------------
# Main

my $force_regen = 0;

if (@ARGV[0] =~ '^-f$') {
  print "Forcing re-generation of CCNF/HIST files\n";
  $force_regen = 1;
  shift @ARGV;
} else {
  print "Generating per-URL list histograms as required\n";
}

foreach (@ARGV) {
  my $ufile = $_;
  my $uname = basename($ufile);
  my $hfile = $uname . ".hist";
  my $lhfile = $uname . ".ccnf.lhist";
  my $ccnfile = $uname . ".ccnf";

  if (! -e $ufile) {print "CANNOT OPEN FILE $ufile\n"; exit;}
  push @FILELIST, $hfile;

  print "Checking $hfile and $ccnfile... ";
  if (! $force_regen &&
      ((-e $hfile && (-M $ufile >= -M $hfile)) && 
       (-e $lhfile && (-M $ufile >= -M $lhfile)) && 
       (-e $ccnfile && (-M $ufile >= -M $ccnfile)))) {
    print "READING histogram... ";
    open(HFILE, "<$hfile") || die "Cannot open $hfile for reading\n";
    while (<HFILE>) {
      chomp;
      ($index, $count) = split ' ';
      $HIST{$hfile}{$index} = $count;
      $PLENLIST{$index} = 1;

    }
    close HFILE;
    print "READING length histogram... ";
    open(LHFILE, "<$lhfile") || die "Cannot open $lhfile for reading\n";
    while (<LHFILE>) {
      chomp;
      ($index, $count) = split ' ';
      $LHIST{$hfile}{$index} = $count;
      $PLLENLIST{$index} = 1;
    }
    close HFILE;
    print "SKIPPED\n";
    next;
  }

  print "    REGENERATING... \n";
  open(UFILE, "<$ufile") || die "Cannot open $ufile for reading\n";
  open(HFILE, ">TMP.hf") || die "Cannot open TMP.hf for writing\n";
  open(CCNFILE, ">:raw", "TMP.ccnf") || die "Cannot open TMP.ccnf for writing\n";

  while (<UFILE>) {
    chomp;
    $orig = $_;

    # Drop http:// if present
    s/^http:\/\///;
    s/^https:\/\///;

    # Remove zero length components
    s/\/+/\//g;

    # Split the URL into hostname, path and querystring
    ($hostpath, $urlquery) = split '\?', $_, 2;
    ($hostname, $urlpath) = split '/', $hostpath, 2;
    #if (length ($urlquery) > 0) { 
    #  print $orig . " >H " . $hostname . " >P " . $urlpath . " >Q [" . $urlquery . "] \n"; 
    #}
    @ccncomponents = ();
    # CCN-ize the hostname but only if it is not an IP address
    if ($hostname =~ /^\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}/) {
      @ccncomponents[0] = $hostname;
    } else {
      @ccncomponents = reverse (split '\.',$hostname);
    }
    push @ccncomponents, (split '/', $urlpath);
    if (length ($urlquery) > 0) { 
      push @ccncomponents, $urlquery;
    }

    my $numcomponents = (scalar @ccncomponents);

    # Skip junk lines
    next if ($numcomponents == 0);

    #if (length ($urlquery) >= 0) 
    #{ 
    #  print $orig . " " . (join '|', @ccncomponents) . "\n";
    #  print $numcomponents . "|>" . $totlength;
    #}

    # Write output to file

    print CCNFILE ccnf_pack_uri(@ccncomponents);

    #if (length ($urlquery) >= 0) 
    # { print "\n\n"; }

    $PLENLIST{$numcomponents} = 1;

    # Update histogram
    if (!exists $HIST{$hfile}{$numcomponents}) {
      $HIST{$hfile}{$numcomponents} = 1;
    } else {
      $HIST{$hfile}{$numcomponents} ++;
    }
  }

  # Write histogram to disk
  foreach (sort { $a <=> $b } keys %{$HIST{$hfile}}) {
    print HFILE $_ . " " . $HIST{$hfile}{$_} . "\n";
  }
  close UFILE;
  close HFILE;
  close CCNFILE;
  rename "TMP.hf", $hfile || die "Failed to rename TMP.hf to $hfile\n";
  rename "TMP.ccnf", $ccnfile || die "Failed to rename TMP.ccnf to $ccnfile\n";

}

# Join all the histograms
print "Joining histograms into single joined output\n";

print "Count";
foreach (sort @FILELIST) {
  print ",$_";
}
print "\n";

foreach (sort { $a <=> $b} keys %PLENLIST) {
  my $plen = $_;
  print "$plen";
  foreach (sort @FILELIST) {
    my $pfil = $_;
    if (defined $HIST{$pfil}{$plen}) {
      print ",$HIST{$pfil}{$plen}";
    } else {
      print ",0";
    }
  }
  print "\n";
}

print "Joining name length histograms into single joined output\n";

print "Count";
foreach (sort @FILELIST) {
  print ",$_";
}
print "\n";

foreach (sort { $a <=> $b} keys %PLLENLIST) {
  my $plen = $_;
  print "$plen";
  foreach (sort @FILELIST) {
    my $pfil = $_;
    if (defined $LHIST{$pfil}{$plen}) {
      print ",$LHIST{$pfil}{$plen}";
    } else {
      print ",0";
    }
  }
  print "\n";
}
