#!/usr/bin/perl -w
#
# Neon Goat MP3 Report Generator - mp3report.pl
# Copyright (C) 2000, David Parker, Neon Goat Productions.
# www.neongoat.com - david@neongoat.com
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# See the file COPYING or http://www.gnu.org for more details.

no strict 'refs';
use Getopt::Long;
use IO::File;
use MP3::Info;

my ($tnumdir, $tnumfile, $tsize, $tmin, $tsec) = 0;
my ($template_header, $template_itemheader, $template_itemitem, $template_itemfooter, $template_footer);
my (@dirs, $printmode, $title, $outfile);

# local's necessary for all variables that are to be 'dynamically' interpolated into the HTML template
local $VERSION = "1.0.2";
local ($t_fontsize, $t_title, $t_datetime, $t_dirs, $t_numdirs, $t_numfiles, $t_size, $t_playtime, $t_exectime, $t_avgsize, $t_avgplaytime);
local ($t_filename, $t_template_filename, $t_printmode, $t_customdirs, $t_genretype, $t_id3v2);
local ($item_dir, $item_num, $item_filename, $item_size, $item_bgcolor, $item_len);
local ($item_totalseconds, $item_mp3version, $item_stereo, $item_mpeglayer, $item_bitrate, $item_vbr, $item_copyrighted, $item_frequency, $item_mode);
local ($item_id3title, $item_id3artist, $item_id3album, $item_id3year, $item_id3comment, $item_id3genre, $item_id3tracknum);
# id3v2 local variables defined below if --id3v2 is specified on the cmd line

##########################################################
# my hardcoded defaults, you probably want to change these
##########################################################

$printmode = 0;
## $title = "the mad diPPer's MP3 Catalog";
$title = "[untitled mp3report]";
$outfile = "mp3report.html";
## $dirs[@dirs] = 'C:\Audio\Napster';
## $dirs[@dirs] = 'D:\symphonic iNSANiTY';

##########################################################
# end of config settings
##########################################################

print STDERR "\nNeon Goat MP3 Report Generator v$VERSION";
print STDERR "\nCopyright (C) 2000, David Parker, Neon Goat Productions.";
print STDERR "\nwww.neongoat.com - david\@neongoat.com\n";

my ($longopt_help, $longopt_print, $longopt_title, $longopt_outfile, $longopt_template, $longopt_stdgenres, $longopt_id3v2);
GetOptions("help" => \$longopt_help,
           "printmode" => \$longopt_print,
           "title=s" => \$longopt_title,
           "outfile=s" => \$longopt_outfile,
           "template=s" => \$longopt_template,
           "stdgenres" => \$longopt_stdgenres,
           "id3v2" => \$longopt_id3v2);

if ($longopt_help || (!@ARGV && !@dirs)) {
  print STDERR "\nUsage: $0 [options] [directory...]";
  print STDERR "\n --help\t\t\tshows this help screen";
  print STDERR "\n --printmode\t\tuses a smaller font for printing";
  print STDERR "\n --title=TITLE\t\tsets the title used in the report";
  print STDERR "\n --outfile=OUTFILE\tfile to write report to, '-' for STDOUT";
  print STDERR "\n --template=FILE\tfile to use as report template";
  print STDERR "\n --stdgenres\t\tuse standard genres instead of winamp genres";
  print STDERR "\n --id3v2\t\tenable id3v2 support (experimental)";
  print STDERR "\n directory...\t\tdirs to scan (subdirs included)\n\n";
  exit;
}

if ($longopt_print) { $printmode = 1; }
if ($longopt_title) { $title = $longopt_title; }
if ($longopt_outfile) { $outfile = $longopt_outfile; }
if (!$longopt_stdgenres) { use_winamp_genres(); }
if ($longopt_id3v2) {
  print STDERR "\nWarning: Enabling ID3v2 support. This is still experimental and may act funny.\n";
  # a little hackery to define id3v2 template variables:
  foreach $tag (keys %$MP3::Info::v2_tag_names) {
    eval 'local $item_id3v2_' . lc($tag) . ' = " ";' || die "can't eval for id3v2 tags";
  }
}

my $tmpfile1 = IO::File->new_tmpfile() or die "Unable to create temp file 1 of 2: $!";
my $tmpfile2 = IO::File->new_tmpfile() or die "Unable to create temp file 2 of 2: $!";

$t_filename = $outfile;
$t_template_filename = $longopt_template;
$t_printmode = $printmode ? 'Yes' : 'No';
$t_customdirs = 'No';
$t_genretype = $longopt_stdgenres ? 'Standard' : 'WinAMP';
$t_id3v2 = $longopt_id3v2 ? 'Yes' : 'No';

my $dirsep = ((($^O =~ /MSWin32/i) || ($^O =~ /dos/i)) ? '\\' : (($^O =~ /mac/i) ? ':' : '/'));

if (@ARGV) {
  # clear out hardcoded dirs
  undef @dirs;
  $t_customdirs = 'Yes';
  foreach my $opt_dir (sort @ARGV) {
    $dirs[@dirs] = $opt_dir;
  }
}

foreach my $foo (@dirs) {
  $foo =~ s/($dirsep)*$//i; # nuke trailing slashes
}

my $starttime = (times)[0];
$t_fontsize = ($printmode ? 1 : 2);
$t_title = $title;
open(EET, "> $outfile");

if ($longopt_template) { templatize($longopt_template); }
else { default_templatize(); }

local $item_name;
$item_name = "(\$item_name deprecated, use \$item_filename)";

foreach $dir (sort @dirs) {
  dodir($dir);
}
print STDERR "\n\nWriting report to $outfile...";

$t_datetime = localtime;
$t_dirs = join("<BR>&nbsp;&nbsp;", sort @dirs);
$t_numdirs = $tnumdir;
$t_numfiles = $tnumfile;
$t_size = sprintf("%.2f GB (%.2f MB)", $tsize/1024/1024/1024, $tsize/1024/1024);
$t_playtime = englishtime(60 * $tmin + $tsec);
$t_avgsize = sprintf("%.2f MB", $tsize/1024/1024/$t_numfiles);
$t_avgplaytime = englishtime(sprintf("%.2f", (60 * $tmin + $tsec)/$t_numfiles));

$report_header = $template_header;
$report_footer = $template_footer;
$report_header =~ s/\$(\w+)/${$1}/g;
print EET $report_header;
seek($tmpfile1, 0, 0); # about to slurp in the contents of tempfile
while(<$tmpfile1>) {
  print EET $_;
}
close($tmpfile1);
close($tmpfile2);

$t_exectime = englishtime(sprintf("%.2f", (times)[0]));
$report_footer =~ s/\$(\w+)/${$1}/g;
print EET $report_footer;
close(EET);
print STDERR "\nDone, report generated in $t_exectime!\n";
exit;

sub dodir {
  my $dir = shift;
  if ( -r $dir ) {
    print STDERR "\nScanning $dir...";
  } else {
    print STDERR "\nSkipping $dir...";
    return
  }
  opendir(DIR, $dir) || die("couldn't open dir $dir: $!");
  my @files = sort grep { /\.mp3$/i } readdir(DIR);
  if (@files) {
    my $report_header = $template_itemheader;
    $item_dir = $dir;
    $report_header =~ s/\$(\w+)/${$1}/g;
  }

  truncate($tmpfile2, 0);
  seek($tmpfile2, 0, 0);

  foreach $mp3 (@files) {
    my ($size, $min, $sec, $name);
    $size = (stat($dir.$dirsep.$mp3))[7];
    if (my $mp3info = get_mp3info($dir.$dirsep.$mp3)) {
      $tsize += $size;
      $tmin += $mp3info->{MM};
      $tsec += $mp3info->{SS};
      $tnumfile++;
      $item_num = sprintf("%04u", $tnumfile);
      $item_filename = $mp3;
      $item_size = sprintf("%.2f MB", $size/1024/1024);
      $item_len = sprintf("%02u:%02u", $mp3info->{MM}, $mp3info->{SS});
      $item_bgcolor = ($tnumfile%2) ? "#FFFFFF" : "#EEEEEE";
      $item_totalseconds = $mp3info->{MM}*60 + $mp3info->{SS};
      $item_mp3version = $mp3info->{VERSION};
      $item_stereo = $mp3info->{STEREO} ? Stereo : Mono;
      $item_mpeglayer = $mp3info->{LAYER};
      $item_bitrate = $mp3info->{BITRATE};
      $item_vbr = $mp3info->{VBR} ? VBR : '';
      $item_mode = $mp3info->{MODE};
      $item_copyrighted = $mp3info->{COPYRIGHT} ? Copyrighted : 'Not copyrighted';
      $item_frequency = $mp3info->{FREQUENCY};

      # clear out id3 variables from previous match
      $item_id3title = "";
      $item_id3artist = "";
      $item_id3album = "";
      $item_id3year = "";
      $item_id3comment = "";
      $item_id3genre = "";
      $item_id3tracknum = "";

      if (my $mp3tag = get_mp3tag($dir.$dirsep.$mp3)) {
        $item_id3title = $mp3tag->{TITLE};
        $item_id3artist = $mp3tag->{ARTIST};
        $item_id3album = $mp3tag->{ALBUM};
        $item_id3year = $mp3tag->{YEAR};
        $item_id3comment = $mp3tag->{COMMENT};
        $item_id3genre = $mp3tag->{GENRE};
        $item_id3tracknum = $mp3tag->{TRACKNUM};
      }

      # clear out id3v2 variables from previous match
      foreach $tag (keys %MP3::Info::v2_tag_names) {
        eval '$item_id3v2_' . lc($tag) . ' = "";';
      }

      if ($longopt_id3v2 && (my $mp3tag_id3v2 = get_mp3tag($dir.$dirsep.$mp3, 2, 1))) {
        # fill in id3v2 tags
        foreach $tag (keys %MP3::Info::v2_tag_names) {
          eval '$item_id3v2_' . lc($tag) . ' = defined($mp3tag_id3v2->{$tag}) ? $mp3tag_id3v2->{$tag} : "";';
        }
      }

      $report_item = $template_itemdata;
      $report_item =~ s/\$(\w+)/${$1}/g;
      print $tmpfile2 $report_item;
    }
    else { print STDERR "\nWarning: $dir$dirsep$mp3 is not a valid MP3, skipping..."; }
  }

  if (@files) {
    my $report_header = $template_itemheader;
    $item_dir = $dir;
    $report_header =~ s/\$(\w+)/${$1}/g;
    print $tmpfile1 $report_header;
  }

  seek($tmpfile2, 0, 0);
  while(<$tmpfile2>) {
    print $tmpfile1 $_;
  }
  truncate($tmpfile2, 0);
  seek($tmpfile2, 0, 0);

  closedir(DIR);
  if (@files) { print $tmpfile1 $template_itemfooter; }
  opendir(SUBDIR, $dir) || die("couldn't open subdir $dir: $!");
  foreach $subdir (sort grep { -d } map { $dir.$dirsep.$_ } grep { !/^\./ } readdir(SUBDIR)) {
    dodir($subdir);
  }
  $tnumdir++;
}

sub englishtime {
  my $tsec = shift;
  my ($english, @fragments);
  my $flub = int($tsec/60/60/24);
  if ($flub > 0) {
    $fragments[@fragments] = "$flub day" . (($flub != 1) ? 's' : '');
    $tsec -= $flub*60*60*24;
  }
  $flub = int($tsec/60/60);
  if ($flub > 0) {
    $fragments[@fragments] = "$flub hour" . (($flub != 1) ? 's' : '');
    $tsec -= $flub*60*60;
  }
  $flub = int($tsec/60);
  if ($flub > 0) {
    $fragments[@fragments] = "$flub minute" . (($flub != 1) ? 's' : '');
    $tsec -= $flub*60;
  }
  if ($tsec) {
    $fragments[@fragments] = "$tsec second" . (($tsec != 1) ? 's' : '');
  }

  $english = (@fragments == 0) ? '' : (@fragments == 1) ? $fragments[0] : (@fragments == 2) ? join(" and ", @fragments) : join(", ", @fragments[0 .. ($#fragments-1)], "and $fragments[-1]");

  return $english;
}

sub templatize {
  my $template = shift;
  my $slurped;
  my $parsepos = 0;
  my @parsetokens = qw(START_TEMPLATE_HEADER END_TEMPLATE_HEADER START_TEMPLATE_ITEMHEADER END_TEMPLATE_ITEMHEADER START_TEMPLATE_ITEMDATA END_TEMPLATE_ITEMDATA START_TEMPLATE_ITEMFOOTER END_TEMPLATE_ITEMFOOTER START_TEMPLATE_FOOTER END_TEMPLATE_FOOTER);
  my $parseline = '<!-- %% token %% - DO NOT TOUCH THIS LINE. IT MUST BE ON A LINE BY ITSELF. -->';

  open(TEMPLATE, "< $template") || die "can't open template file $template: $!";
  #slurp whole file
  my $oldslurp = $/;
  undef $/;
  $slurped = <TEMPLATE>;
  close(TEMPLATE);
  $/ = $oldslurp;

  while ($parsepos < @parsetokens-1) {
    my $slurped2 = $slurped;
    my ($parsebegin, $parseend);
    $parsebegin = $parseend = $parseline;
    my $section = $parsetokens[$parsepos]; $section =~ s/START_TEMPLATE_(.*)/\L$1/g;
    $parsebegin =~ s/token/$parsetokens[$parsepos]/g;
    $parseend =~ s/token/$parsetokens[$parsepos+1]/g;
    $slurped2 =~ s/.*$parsebegin(.*)$parseend.*/$1/s; ####### WTF ISNT /s THE DEFAULT!$!%@ GRRRRR
    eval '$template_' . $section . ' = $slurped2;';
    $parsepos += 2;
  }
}

sub default_templatize {

$template_header = <<'EET';
<HTML>
<HEAD>
<TITLE>$t_title</TITLE>
</HEAD>
<BODY>

<!-- Report generated by Neon Goat MP3 Report Generator v$VERSION -->
<!-- Copyright (C) 2000, David Parker, Neon Goat Productions -->
<!-- http://www.neongoat.com -->

<!--
Using template: (builtin default)
Outputting to: $t_filename
Using print mode? $t_printmode
Scanning user-specified directories? $t_customdirs
Using genre type: $t_genretype
ID3v2 support loaded? $t_id3v2
-->

<B><FONT SIZE="6" FACE="Verdana,Tahoma,Arial,sans-serif">$t_title</FONT></B><BR><BR>
<HR ALIGN="left" WIDTH="90%" NOSHADE COLOR="#000000">
<P><FONT FACE="Verdana,Tahoma,Arial,sans-serif" SIZE="$t_fontsize"><B>Generated:</B> $t_datetime by <A HREF="http://www.neongoat.com">Neon Goat MP3 Report Generator</A></FONT></P>
<P><FONT FACE="Verdana,Tahoma,Arial,sans-serif" SIZE="$t_fontsize"><B>Scanned directories:</B><BR>&nbsp;&nbsp;$t_dirs</FONT></P>
<TABLE BORDER="0" CELLSPACING="0" CELLPADDING="0">
  <TR>
    <TD ALIGN="right"><FONT FACE="Verdana,Tahoma,Arial,sans-serif" SIZE="$t_fontsize"><B>Total number of dirs:</B></FONT></TD>
    <TD ALIGN="left"><FONT FACE="Verdana,Tahoma,Arial,sans-serif" SIZE="$t_fontsize">&nbsp;&nbsp;$t_numdirs</FONT></TD>
  </TR>
  <TR>
    <TD ALIGN="right"><FONT FACE="Verdana,Tahoma,Arial,sans-serif" SIZE="$t_fontsize"><B>Total number of files:</B></FONT></TD>
    <TD ALIGN="left"><FONT FACE="Verdana,Tahoma,Arial,sans-serif" SIZE="$t_fontsize">&nbsp;&nbsp;$t_numfiles</FONT></TD>
  </TR>
  <TR>
    <TD ALIGN="right"><FONT FACE="Verdana,Tahoma,Arial,sans-serif" SIZE="$t_fontsize"><B>Average file size:</B></FONT></TD>
    <TD ALIGN="left"><FONT FACE="Verdana,Tahoma,Arial,sans-serif" SIZE="$t_fontsize">&nbsp;&nbsp;$t_avgsize</FONT></TD>
  </TR>
  <TR>
    <TD ALIGN="right"><FONT FACE="Verdana,Tahoma,Arial,sans-serif" SIZE="$t_fontsize"><B>Average playing time:</B></FONT></TD>
    <TD ALIGN="left"><FONT FACE="Verdana,Tahoma,Arial,sans-serif" SIZE="$t_fontsize">&nbsp;&nbsp;$t_avgplaytime</FONT></TD>
  </TR>
  <TR>
    <TD ALIGN="right"><FONT FACE="Verdana,Tahoma,Arial,sans-serif" SIZE="$t_fontsize"><B>Total size of files:</B></FONT></TD>
    <TD ALIGN="left"><FONT FACE="Verdana,Tahoma,Arial,sans-serif" SIZE="$t_fontsize">&nbsp;&nbsp;$t_size</FONT></TD>
  </TR>
  <TR>
    <TD ALIGN="right"><FONT FACE="Verdana,Tahoma,Arial,sans-serif" SIZE="$t_fontsize"><B>Total playing time:</B></FONT></TD>
    <TD ALIGN="left"><FONT FACE="Verdana,Tahoma,Arial,sans-serif" SIZE="$t_fontsize">&nbsp;&nbsp;$t_playtime</FONT></TD>
  </TR>
</TABLE>
<BR>
EET

$template_itemheader = <<'SUM';
<TABLE BORDER="0" WIDTH="100%" CELLSPACING="0" CELLPADDING="1" BGCOLOR="#000080">
  <TR>
    <TD WIDTH="100%" ALIGN="left" VALIGN="middle"><B><FONT COLOR="#FFFFFF" SIZE="$t_fontsize" FACE="Verdana,Tahoma,Arial,sans-serif">&nbsp;$item_dir</FONT></B></TD>
  </TR>
</TABLE>
<TABLE BORDER="0" WIDTH="100%" BGCOLOR="#000080" CELLSPACING="0" CELLPADDING="2">
  <TR>
    <TD WIDTH="100%">
      <TABLE BORDER="0" WIDTH="100%" CELLSPACING="0" CELLPADDING="2" BGCOLOR="#FFFFFF">
SUM

$template_itemdata = <<'KEGS';
        <TR>
          <TD WIDTH="5%" BGCOLOR="$item_bgcolor"><FONT SIZE="$t_fontsize" FACE="Verdana,Tahoma,Arial,sans-serif"><B>$item_num.&nbsp;</B></FONT></TD>
          <TD WIDTH="90%" BGCOLOR="$item_bgcolor"><FONT SIZE="$t_fontsize" FACE="Verdana,Tahoma,Arial,sans-serif">$item_filename <FONT COLOR="#FF0000"><STRONG>$item_vbr</STRONG></FONT></FONT></TD>
          <TD WIDTH="5%" BGCOLOR="$item_bgcolor"><FONT SIZE="$t_fontsize" FACE="Verdana,Tahoma,Arial,sans-serif">$item_len</FONT></TD>
        </TR>
KEGS

$template_itemfooter = <<'OF';
      </TABLE>
    </TD>
  </TR>
</TABLE>
OF

$template_footer = <<'DIP';
<P><FONT FACE="Verdana,Tahoma,Arial,sans-serif" SIZE="$t_fontsize">Report completed in $t_exectime.</FONT></P>
<HR ALIGN="left" WIDTH="90%" NOSHADE COLOR="#000000">
<P><FONT FACE="Verdana,Tahoma,Arial,sans-serif" SIZE="$t_fontsize">This report was generated with <A HREF="http://www.neongoat.com">Neon Goat MP3 Report Generator</A>.<BR>
Copyright © 2000, David Parker, Neon Goat Productions. All rights reserved.<BR>
This software is released under the GNU Genereal Public Licence, see <A HREF="http://www.gnu.org">http://www.gnu.org</A> for more details.</FONT></P>

</BODY>
</HTML>
DIP
}

__END__

=pod

=head1 NAME

Neon Goat MP3 Report Generator - mp3report.pl

=head1 DESCRIPTION

 A customizable program to scan a list of (sub)directories, creating a report
 from an HTML template. Also calculates various statistics and each song's
 playing time. Supports ID3 and ID3v2 tags. Should work on any perl-ized OS;
 see homepage for demo - http://mp3report.sourceforge.net

=head1 CONFIGURING

 All options can be configured through the command line, see mp3report.pl --help
 for more info. You may also want to modify the hard coded defaults at the
 top of the program file.

 See documentation.html for information on customizing your own template file.

=head1 USAGE

 Usage: mp3report.pl [options] [directory...]
  --help                 shows this help screen
  --printmode            uses a smaller font for printing
  --title=TITLE          sets the title used in the report
  --outfile=OUTFILE      file to write report to, '-' for STDOUT
  --template=FILE        file to use as report template
  --stdgenres            use standard genres instead of winamp genres
  --id3v2                enable id3v2 support (experimental)
  directory...           dirs to scan (subdirs included)

=head1 INSTALLATION

 You should be able to run mp3report.pl directly after decompressing it:
 
 tar xfzv mp3report-1.0.2.tar.gz
 cd mp3report-1.0.2
 ./mp3report.pl --help
 
 If your perl interpreter isn't in /usr/bin/perl, you'll need to change the first line
 of mp3report.pl
 
 If you'd like to install the MP3::Info perl module so that other programs can
 use it, it is available at http://search.cpan.org/search?dist=MP3-Info.

=head1 CUSTOMIZATION AND TEMPLATES

By creating your own HTML file or modifying one of the provided templates, you can customize the output of MP3 Report Generator. These are the various identifiers that MP3 Report Generator can look for in a report:

=head2 General Information

=over 4

=item $t_fontsize

This is either 1 or 2, depending on the C<--printmode> flag. If printing mode is on, the idea is that the font size should be a little bit smaller so that it looks better on paper. To make sure this field does something, use C<<FONT SIZE="$t_fontsize">> in your HTML code.

=item $t_title

Used for the HTML C<<TITLE>> tag as well as the first line of the report, and is set by specifying C<--title=SOMETHING> on the command line.

=item $t_datetime

The local date and time when the report was generated.

=item $t_dirs

The list of parent directories that was scanned in the report. Each directory is separated by C<<BR&gt;&amp;nbsp;&amp;nbsp;> so that they are on seperate lines and indented.

=item $t_numdirs

The total number of directories and subdirectories scanned in the report.

=item $t_numfiles

The total number of MP3 files included in the report.

=item $t_size

The total size of all MP3 files included in the report combined. This is formatted into "x.xx GB (y.yy MB)".

=item $t_playtime

The total playing time of all songs combined. This is formatted into an English sentence (4 days, 3 hours, 2 minutes, 1 second).

=item $t_exectime

The total time it took to genereate the report. This is formatted into an English sentence (4 days, 3 hours, 2 minutes, 1 second).

=item $t_avgsize

The average size of the MP3s in this report. This is formatted into "x.xx MB".

=item $t_avgplaytime

The average playing time of a single song in the report. This is formatted into an English sentence (3 hours, 2 minutes, 1 second).

=back

=head2 Report Settings

=over 4

=item $t_filename

The filename that the report is being written to.

=item $t_template_filename

The filename of the template that is being used.

=item $t_printmode

Either "Yes" or "No" depending on whether the C<--printmode> flag was specified.

=item $t_customdirs

Either "Yes" or "No" depending on whether user specified custom directories to scan on the command line.

=item $t_genretype

Either "Standard" or "WinAMP" depending on whether or not the user specified C<--stdgenres>.

=item $t_id3v2

Either "Yes" or "No" depending on whether the C<--id3v2> flag was specified.

=back

=head2 Item Information

=over 4

=item $item_dir

The current directory that is being scanned.

=item $item_num

The current sequential number of the item found.

=item $item_filename

The filename of the item found. NOTE: This in versions older than 1.0.2, this variable was called $item_name.

=item $item_size

The size of the item found. This is formatted into "x.xx MB".

=item $item_bgcolor

This will either be C<#FFFFFF> or C<#EEEEEE> (white or light gray) depending on whether or not the current item number is even or odd. This is used to make the cell color in tables alternate to make the report easier to read. In order for this to work, your HTML code must look something like C<E<lt>TD BGCOLOR="$item_bgcolor"E<gt>>C<...E<lt>/TDE<gt>>.

=item $item_len

The playing time of the song found, formatted into "XX:YY" (minutes:seconds).

=back

=head2 MP3 Information

=over 4

=item $item_totalseconds

The total number of seconds in the current song.

=item $item_mp3version

The MPEG version number of the current MP3, usually 1.

=item $item_stereo

Either "Stereo" or "Mono" depending on the number of channels in the MP3.

=item $item_mpeglayer

The MPEG layer number, usually 3.

=item $item_bitrate

The bitrate of the current MP3 in kbps.

=item $item_vbr

If the current MP3 is encoded at a variable bitrate, this will equal "VBR". If not, it will be a blank string.

=item $item_copyrighted

Either "Copyrighted" or "Not copyrighted" depending on the MP3's copyright flag.

=item $item_frequency

The frequency of the current MP3 in kHz.

=back

=head2 ID3 Tag Information

=over 4

=item $item_id3title

The song's ID3 title, maximum 30 characters.

=item $item_id3artist

The song's ID3 artist, maximum 30 characters.

=item $item_id3album

The song's ID3 album, maximum 30 characters.

=item $item_id3year

The song's ID3 year, maximum 4 characters.

=item $item_id3comment

The song's ID3 comment, maximum 30 characters (28 if the ID3 tag also contains a track number).

=item $item_id3genre

The song's ID3 genre. You may disable WinAMP genres by specifying the C<--stdgenres> flag.

=item $item_id3tracknum

The song's ID3v1.1 track number (if present), maximum 2 characters.

=back

=head2 ID3v2 Tag Information

ID3v2.3.0 (or later) tags are also supported. To enable ID3v2 support, use the C<--id3v2> flag on the command line. The following is taken from C<MPEG::MP3Info::v2_tag_names>

=over 4

=item $item_id3v2_wpay

WPAY: Payment

=item $item_id3v2_text

TEXT: Lyricist/Text writer

=item $item_id3v2_toly

TOLY: Original lyricist(s)/text writer(s)

=item $item_id3v2_tmed

TMED: Media type

=item $item_id3v2_rvad

RVAD: Relative volume adjustment

=item $item_id3v2_time

TIME: Time

=item $item_id3v2_rbuf

RBUF: Recommended buffer size

=item $item_id3v2_toal

TOAL: Original album/movie/show title

=item $item_id3v2_trck

TRCK: Track number/Position in set

=item $item_id3v2_ipls

IPLS: Involved people list

=item $item_id3v2_mllt

MLLT: MPEG location lookup table

=item $item_id3v2_tkey

TKEY: Initial key

=item $item_id3v2_apic

APIC: Attached picture

=item $item_id3v2_sytc

SYTC: Synchronized tempo codes

=item $item_id3v2_tyer

TYER: Year

=item $item_id3v2_tpos

TPOS: Part of a set

=item $item_id3v2_trsn

TRSN: Internet radio station name

=item $item_id3v2_ufid

UFID: Unique file identifier

=item $item_id3v2_trso

TRSO: Internet radio station owner

=item $item_id3v2_tsiz

TSIZ: Size

=item $item_id3v2_tenc

TENC: Encoded by

=item $item_id3v2_trda

TRDA: Recording dates

=item $item_id3v2_comm

COMM: Comments

=item $item_id3v2_sylt

SYLT: Synchronized lyric/text

=item $item_id3v2_woaf

WOAF: Official audio file webpage

=item $item_id3v2_link

LINK: Linked information

=item $item_id3v2_comr

COMR: Commercial frame

=item $item_id3v2_tbpm

TBPM: BPM (beats per minute)

=item $item_id3v2_pcnt

PCNT: Play counter

=item $item_id3v2_tofn

TOFN: Original filename

=item $item_id3v2_woar

WOAR: Official artist/performer webpage

=item $item_id3v2_woas

WOAS: Official audio source webpage

=item $item_id3v2_tpe1

TPE1: Lead performer(s)/Soloist(s)

=item $item_id3v2_tflt

TFLT: File type

=item $item_id3v2_tpe2

TPE2: Band/orchestra/accompaniment

=item $item_id3v2_tsrc

TSRC: ISRC (international standard recording code)

=item $item_id3v2_tpe3

TPE3: Conductor/performer refinement

=item $item_id3v2_rvrb

RVRB: Reverb

=item $item_id3v2_tpe4

TPE4: Interpreted, remixed, or otherwise modified by

=item $item_id3v2_mcdi

MCDI: Music CD identifier

=item $item_id3v2_tdly

TDLY: Playlist delay

=item $item_id3v2_tdat

TDAT: Date

=item $item_id3v2_tory

TORY: Original release year

=item $item_id3v2_tlan

TLAN: Language(s)

=item $item_id3v2_tcom

TCOM: Composer

=item $item_id3v2_tlen

TLEN: Length

=item $item_id3v2_tcon

TCON: Content type

=item $item_id3v2_tcop

TCOP: Copyright message

=item $item_id3v2_owne

OWNE: Ownership frame

=item $item_id3v2_tpub

TPUB: Publisher

=item $item_id3v2_txxx

TXXX: User defined text information frame

=item $item_id3v2_geob

GEOB: General encapsulated object

=item $item_id3v2_tsse

TSSE: Software/Hardware and settings used for encoding

=item $item_id3v2_priv

PRIV: Private frame

=item $item_id3v2_tit1

TIT1: Content group description

=item $item_id3v2_talb

TALB: Album/Movie/Show title

=item $item_id3v2_tit2

TIT2: Title/songname/content description

=item $item_id3v2_tit3

TIT3: Subtitle/Description refinement

=item $item_id3v2_poss

POSS: Position synchronisation frame

=item $item_id3v2_grid

GRID: Group identification registration

=item $item_id3v2_uslt

USLT: Unsychronized lyric/text transcription

=item $item_id3v2_encr

ENCR: Encryption method registration

=item $item_id3v2_town

TOWN: File owner/licensee

=item $item_id3v2_wors

WORS: Official internet radio station homepage

=item $item_id3v2_etco

ETCO: Event timing codes

=item $item_id3v2_equa

EQUA: Equalization

=item $item_id3v2_wcom

WCOM: Commercial information

=item $item_id3v2_aenc

AENC: Audio encryption

=item $item_id3v2_tope

TOPE: Original artist(s)/performer(s)

=item $item_id3v2_wcop

WCOP: Copyright/Legal information

=item $item_id3v2_popm

POPM: Popularimeter

=item $item_id3v2_wpub

WPUB: Publishers official webpage

=item $item_id3v2_wxxx

WXXX: User defined URL link frame

=item $item_id3v2_user

USER: Terms of use

=back

=head1 ACKNOWLEDGEMENTS

 Much thanks to Chris Nandor and contributors to MP3::Info... 
 it saved me a lot of time :) And to Larry Wall for such a great language.
 
 Hello to MMT, UCLA LUG, cX, and of course the DJs of Mister Balak's Neighborhood!

=head1 SEE ALSO

=over 4

=item MP3::Info

http://search.cpan.org/search?dist=MP3-Info

=item ID3v2

http://www.id3.org/

=item SourceForge

http://www.sourceforge.net
Damn, these guys rock.

=item icecast

http://www.icecast.org

=back

=head1 AUTHOR AND COPYRIGHT

 Neon Goat MP3 Report Generator
 v1.0.2 - April 5, 2000
 Copyright (C) 2000, David Parker, Neon Goat Productions.
 
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 See COPYING or http://www.gnu.org for more information.
 
 David Parker
 david@neongoat.com
 http://www.neongoat.com
 http://mp3report.sourceforge.net

=cut

# following snippet lists all id3v2 tags, mostly fro debugging

#    my $tag = get_mp3tag('D:\symphonic iNSANiTY!\_dump\(_music.mp3', 2, 1);
#    for (keys %$tag) {
#        printf "%s => %s\n", $MPEG::MP3Info::v2_tag_names{$_}, $tag->{$_};
#    }

# following snippet makes POD documentation for ID3v2 variables

#open(FILE, "> tmpfoo.txt");
#for (keys %MPEG::MP3Info::v2_tag_names) {
#  print FILE "\n\n=item \$item_id3v2_" . lc($_) . "\n\n$_: " . $MPEG::MP3Info::v2_tag_names{$_};
#}
#close(FILE);
