ndn-trace-script
================

NDN Trace Script
Copyright (c) 2012-2013 by Cisco Systems, Inc.
All rights reserved.
Written by Ashok Narayanan and Won So

This software suite provides Perl scripts that can be used to traslate HTTP URL traces into NDN names.

url2ccnf.pl: This script converts plain text files with HTTL URLs into CCNF (Common Componentized Name Format - see another document) format files simultaneously generating the historgram of named components in the input files.

build_fib.pl: Given a set of names from CCNF files, this script builds a FIB name trace that satifies a specific component name distribution. 

ccnfdump.pl: This utility script decode names in a CCNF file and displays in a plain text.

For more details, refer comments in script souce files and the paper published based on the data generated from these scripts:
Won So, Ashok Narayanan, and David Oran, Named data networking on a router: fast and DoS-resistant forwarding with hash tables, In Proceedings of the 2013 ACM/IEEE Nineth Symposium on Architectures for Networking and Communications Systems, Oct. 2013.

HTTP URL traces can be obtained from independent sources.
E.g. IRCache trace: ftp://ircache.net/Traces/DITL-2007-01-09
