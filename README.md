# Licensing

Neon Goat MP3 Report Generator
v1.0.2 - April 5, 2000
Copyright (C) 2000, David Parker, Neon Goat Productions.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

See COPYING or http://www.gnu.org for more information.


# Neon Goat MP3 Report Generator

A customizable program to scan a list of (sub)directories, creating a report
from an HTML template. Also calculates various statistics and each song's
playing time. Supports ID3 and ID3v2 tags. Should work on any perl-ized OS;
see homepage for demo (http://mp3report.sourceforge.net).


# Configuring

All options can be configured through the command line, see mp3report.pl --help
for more info. You may also want to modify the hard coded defaults at the
top of the program file.

See documentation.html for information on customizing your own template file.


# Usage

Neon Goat MP3 Report Generator v1.0.2
Copyright (C) 2000, David Parker, Neon Goat Productions.
www.neongoat.com - david@neongoat.com

```
Usage: mp3report.pl [options] [directory...]
 --help                 shows this help screen
 --printmode            uses a smaller font for printing
 --title=TITLE          sets the title used in the report
 --outfile=OUTFILE      file to write report to, '-' for STDOUT
 --template=FILE        file to use as report template
 --stdgenres            use standard genres instead of winamp genres
 --id3v2                enable id3v2 support (experimental)
 directory...           dirs to scan (subdirs included)
```

# Installing mp3report

You should be able to run mp3report.pl directly after decompressing it:

```
tar xfzv mp3report-1.0.2.tar.gz
cd mp3report-1.0.2
./mp3report.pl --help
```

If your perl interpreter isn't in /usr/bin/perl, you'll need to change the first line
of mp3report.pl

If you'd like to install the MP3::Info perl module so that other programs can
use it, it is available at http://search.cpan.org/search?dist=MP3-Info.


# Acknowledgements

Of course, much thanks to Chris Nandor and contributors to MP3::Info... 
it saved me a lot of time :) And to Larry Wall for such a great language.

Hello to MMT, UCLA LUG, cX, and of course the DJs of Mister Balak's Neighborhood!

David Parker
david@neongoat.com
http://www.neongoat.com
http://mp3report.sourceforge.net

