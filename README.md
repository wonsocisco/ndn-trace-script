ndn-trace-script
================

NDN Trace Script
Copyright (c) 2012-2013 by Cisco Systems, Inc.
All rights reserved.
Written by Ashok Narayanan and Won So

This software suite provides Perl scripts that can be used to traslate HTTP URL traces into NDN names.

url2ccnf.pl
This script converts plain text files with HTTL URLs into CCNF (Common Componentized Name Format - see the attached) format files simultaneously generating the historgram of named components in the input files.

build_fib.pl
Given a set of names from CCNF files, this script builds a FIB name trace that satifies a specific component name distribution. 

ccnfdump.pl
This utility script decode names in a CCNF file and displays in a plain text.

For more details, refer comments in script souce files and the paper published based on the data generated from these scripts:
Won So, Ashok Narayanan, and David Oran, Named data networking on a router: fast and DoS-resistant forwarding with hash tables, In Proceedings of the 2013 ACM/IEEE Nineth Symposium on Architectures for Networking and Communications Systems, Oct. 2013.

HTTP URL traces can be obtained from independent sources.
E.g. IRCache trace: ftp://ircache.net/Traces/DITL-2007-01-09


Attached: Common Componentized Name Format
----------------------------------
Common Componentized Name Format
----------------------------------

1. Overview

This page describes a common format to store and represent tokenized names.

2. Common Componentized Name Format (CCNF) definition

There is a need for an efficient way to represent tokenized names, for testing tools, hash testing, actual packets etc. This is our proposed format:

Tokenized-Name := <Num-Components> <Name-Length> <Component> [<Component ...]


Num-Tokens := {1 byte, Number of components in name}


Name-Length := {2 bytes, cumulative length of all components in bytes, not including the <Num-Tokens> or <Name-Length> fields }


Component := {Component-length} {Component bytes...}


Component-Length := {1- or 2 bytes, encoded length of component string not including this field}

The Component-Length field is encoded as follows:

- If the top bit of the first byte is 0 (i.e. <128), the lower 7 bits encode the total length of that component (used for components up to 127 bytes long)
- If the top 4 bit of the first byte are 1000, the component length is 12 bits long, with the lower 4 bits of the first byte and all 8 bits of the second byte encoding the component length. The lower 4 bits of the first byte form the 4 most significant bits of the composed length. 
- Top 4 bit values of 1001-1111 are currently reserved for special-purpose components as yet undefined

3. Encoding examples

Here are some encoded examples of URI-style component names.

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

4. Sample code

Here is sample C code to read in

- PERL code

Here are PERL routines to read in CCNF names from a file and unpack them into string arrays, and pack string arrays into CCNF format
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
        $offset++;
        }
        push @uri, substr $buf, $offset+1, $complen;
        $offset += $complen + 1;
    }
    }
    return ($numtok, $len, @uri);
}
 
 
# Sample code to use ccnf_read_uri to read a file
# and dump all the URIs to stdout
  open(CCNFILE, "<:raw", $_) || die "Cannot open $_ file reading\n";
  while (1) {
      my ($numtok, $len, @uri) = ccnf_read_uri(CCNFILE);
      last if ($numtok == 0);
      print "$count $numtok $len " . (join "/", @uri) . "\n";
      $count++;
  }
  close CCNFILE;

And code to pack URIs represented as arrays of component strings, into CCNF format
# ------------------------------------------------------------------------------
# ccnf_pack_uri
#
# Takes an array of components and returns a packed CCNF URI
#
sub ccnf_pack_uri {
    my $line = "", $totlength ;
    my $totlength = (length (join " ", @_)) + 1;
    my $numcomponents = (scalar @_);
    #print "\n||$numcomponents||$totlength||";
    foreach (@_) {
    if (length > 127) {
        $line .= pack ( "S>A*", (32768 | length), $_);
        $totlength ++;
        #print "|>" . length . "|" . $_;
    } elsif (length > 0) {
        $line .= pack ( "CA*", length, $_);
        #print "|" . length . "|" . $_;
    }
    }
    return pack ( "CS>A*", $numcomponents, $totlength, $line);
}
 
 
# Sample code to use ccnf_pack_uri to write a CCND
# file out of a list of URIs in uri_array
# here uri_array is an array of arrays (each element
# is a component of a URI
foreach (@uri_array) {
   print FIBFILE ccnf_pack_uri(@{$_});
}
