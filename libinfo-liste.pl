#!/usr/bin/perl -w

# libinfo-liste.pl - schreibe libinfo.html
# history:
#   08.07.1999 ava
#   14.03.2005 portiert auf server
#   07.12.2007 V18 (blu)
#   24.05.2010 V20 (blu)
#   13.06.2012 UTF-8 (ava)
#   04.04.2013 V21 (blu)
#   28.05.2014 V22 (blu)
#   28.05.2018 Anpassungen fuer die virtuelle Umgebung unter RedHat (fbo)

use strict;
use vars qw( %sublibs );
use Encode;
use POSIX qw(strftime);
require 'masterfile.pl';

my $IN  = 'libinfo.txt';
my $OUT = 'libinfo.html';

my %urls;
open(IN, "<$IN" ) or die "cannot read $IN: $!";
while( <IN> ) {
    next if ( /^#/ );
    next if ( /^\s*$/ );
    chomp;
    my ( $file, $url ) = split /\s+/;
    $file =~ s/^library-(.*)\.html$//;
    my $sublib = uc($1);
    $urls{$sublib} = $url;
}
close IN;

my $Page = <<EOD;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<title>IDS Basel/Bern: Aleph Bibliotheksinformation</title>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<style type="text/css">
<!--
body,td { font-family:Arial,SansSerif; font-size:80%; }
td.bar { background:#ffcc66; }
//-->
</style>
</head>
<body>
<table summary="" border="0" cellpadding="5" cellspacing="0" width="100%">
<tr><td class="bar"><big><big>IDS Basel/Bern: Bibliotheksinformation</big></big>
</td></tr></table>
<br>
<table>
<tr><td valign="top"><img src="http://alephtest.unibas.ch/exlibris/aleph/u22_1/dsv01/www_f_ger/icon/f-info.gif"
border="0" alt="Bibliotheksinfo"></td>
<td>Liste der Seiten, die in Aleph als Bibliotheksinformation angezeigt werden.<br>
F&uuml;r Bibliotheken, f&uuml;r die keine eigene Bibliotheksinfo definiert ist, wird eine
<a href="http://aleph.unibas.ch/F?func=library&sub_library=ZZZZ">Default-Seite</a> angezeigt</td></tr>
<tr><td>Stand:</td><td>%%DATUM%%</td></tr>
<tr><td>URL:</td><td>http://alephtest.unibas.ch/dirlist/u/local/sublib/libinfo.html</td></tr>
</table>
<br>
<table summary="" cellspacing="0" cellpadding="3">
%%TABLE%%
</table>
<hr size="1" />
<p>UB Basel EDV</p>
</body>
</html>
EOD

my $Table = qq|<tr><td class="bar" colspan="3"><b>Basel</b></td></tr>\n|
    .qq|<tr><td><b>Sublibrary</b></td><td><b>Name</b></td><td><b>URL der Bibliotheksinfo</b></td></tr>\n|;

(my $HeaderBern = $Table) =~ s|Basel|Bern|;

# Loop ueber Sublibs aus dem Masterfile
foreach my $sublib( sort keys(%sublibs) ) {
    my $name = $sublibs{$sublib};
    Encode::from_to($name,'iso-8859-1','utf-8');
    my $url = $urls{$sublib};
    if ( $sublib =~ /^B/ and $HeaderBern ) {
        $Table .= $HeaderBern;
        $HeaderBern='';
    }
    my $link = $url ? qq|<a href="$url">$url</a>| : '&nbsp;';
    $Table .= qq|<tr><td>$sublib</td><td>$name</td><td>$link</td></tr>\n|;
}

my $Datum = strftime("%d %B %Y",localtime);


$Page =~ s/%%DATUM%%/$Datum/;
$Page =~ s/%%TABLE%%/$Table/;

open( OUT, ">$OUT" ) or die "cannot write $OUT: $!";
print OUT $Page;
close OUT;
