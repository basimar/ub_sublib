#!/usr/bin/perl -w 

# libinfo-neu.pl - schreibe library-???.html
#
# history
# 25.07.2000/ava
# 30.10.2000: Term::ReadKey
# 09.10.2001: aleph 14.2
# 07.01.2001: rewrite for ssh
# 05.05.2002: ssh 5.2.1
# 22.10.2004: code fuer frameless, eng/deu/fre
# 14.03.2005: portiert auf server
# 26.10.2005: Anpassung an V16/blu
# 07.12.2007: Anpassung an V18/blu
# 05.11.2008: alephe/www_f_lng als targetdir nicht mehr noetig (rpc 001431)
# 24.05.2010: Anpassung an V20/blu
# 04.04.2013: Anpassung an V21/blu
# 28.05.2014: Anpassung an V22/blu
# 28.04.2018: Anpassungen fuer die virtuelle Umgebung unter RedHat/fbo

use strict;
# use Term::ReadKey;
require 'masterfile.pl';

my $IN          = "libinfo.txt";
my $targetdir   = '/exlibris/aleph/u22_1/dsv01/www_f_';
my @lang        = qw ( ger eng fre );
my $PROD        = 'ub-alprod.ub.unibas.ch';
my $TEST        = 'ub-altest.ub.unibas.ch';
my $User        = 'aleph';
my $SCP         = 'scp -q';
my $TmpDir      = 'tmp';

# --------------------------------
# frage Benutzer nach Library Code
# --------------------------------
print<<EOD;

produziert 'library-???.html' und laedt sie auf den Server.
erwartet aktuelle Info in $IN.

Aleph V22: neue Bibliothekinformationsseiten
-------------------------------------------------

EOD
print "sublibrary_code der neuen Bibliothek: ";
$_ = <STDIN>;
chomp;
$_ = lc($_);
# Regex auskommentiert fuer BSSBK/blu
# ( /^[ab]\d{3}/ ) or die "FEHLER: sublibrary_code nicht regelkonform.\nErwartet: Annn oder Bnnn\n";
my $LocalBase = "library-$_.html";

my $THIS_HOST = `hostname`;
chomp $THIS_HOST;
if ( $THIS_HOST eq 'aleph2' ) { $THIS_HOST = $PROD; }
if ( $THIS_HOST eq 'alephtest' )  { $THIS_HOST = $TEST; }

# --------------------------------
# URLs aus der Konkordanzdatei einlesen
# --------------------------------
my($url,$file);
open(IN, "<$IN" ) || die "can't read $IN: $!";
while( <IN> ) {
    next if ( /^#/ );
    next if ( /^\s*$/ );
    chomp;
    ( $file,$url ) = split /\s+/;
    if ( $file eq $LocalBase ) {
        last;
    }
}
if ( $url eq '' ) { die "FEHLER: Kein Eintrag fuer >>$LocalBase<< in $IN\n"; }

# --------------------------------
# write library-???.html
# --------------------------------
my $LocalFile = "$TmpDir/$LocalBase";
open( LINK, ">$LocalFile" ) or die "can't write $LocalBase: $!";
print STDERR "* writing $LocalBase\n";
print LINK <<EOD;
<html>
<head><title></title></head>
<body>
<script type="text/javascript">
<!--
location.replace("$url");
//-->
</script>
</body>
</html>
EOD
close LINK;

# --------------------------------
# upload
# --------------------------------
my @targetfiles;
foreach my $lang ( @lang ) {
    push(@targetfiles, "$targetdir$lang/$LocalBase");
}
upload($PROD);
upload($TEST);

sub upload {
    my $Host = shift;
    print "* uploading files ($Host)\n";
    foreach my $target ( @targetfiles ) {
        print $target, "\n";
        if ( $Host eq $THIS_HOST ) {
            File::Copy::copy($LocalFile, $target);
        }
        else {
            system "$SCP $LocalFile $User\@$Host:$target";
        }
    }
}
