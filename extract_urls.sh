#!/bin/bash
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
#
# This simple shell script reads IRCache .gz files in the current directory
# and generates .url files that contains plain HTTP URLS.
#
FILES=./*.gz
for FILE in $FILES
do
  URLS="${FILE/.gz/.urls}"
  echo "Extracting URLs from $FILE to $URLS"
  zgrep GET $FILE | sed -e 's/.*GET http:\/\/\([^ ]*\).*/\1/' | grep -v " GET " > $URLS
done