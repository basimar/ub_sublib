# make-help-cllib.pl
#
# Schreibt die CCL-Hilfeseite http://aleph.unibas.ch/help-ccllib.html
# Die Informationen dazu stammen aus
# - masterfile.txt  (Sigel und Bezeichnung)
# - libinfo.txt     (Link zur Bibliotheksinfo)
#
# 07.01.2002 rewrite for SSH
# 28.10.2002 PROD host + TEST host
# 26.06.2004 rewrite for 14.2.8 Frameless
# 02.05.2006 rewrite fuer Test-Host und 16.1/ava
# 06.12.2007 V18/ava
# 24.05.2010 V20/blu
# 04.04.2013 V21/blu
# 22.04.2013 FHs/blu
# 28.05.2014 V22/blu
# 16.09.2015 ignore A126/ava

use strict;
use File::Copy;
use HTML::Entities();
use POSIX qw /strftime/;
use vars qw /%sublibs/;
require 'masterfile.pl';

my $libinf   = 'libinfo.txt';       # konkordanz bibliothekscode <-> bibinfo URL
my $helpfile = '/exlibris/aleph/u22_1/alephe/apache/htdocs/help-ccllib.html';  # output
my $Sigel    = 'blu';

# Bibliothekssigel, die nicht aufgefuehrt werden sollen
my %ignore = map {$_=>1} qw(
    A110
    A126
    B450
);

# -- konkordanz bibliothekscode <-> bibinfo URL als Hash einlesen
my %URL;
open(F,"<$libinf") or die "cannot read $libinf: $!";
my @tmp = grep { ! /^#/ } <F>;
close F;
while ( @tmp ) {
    chomp;
    $_ = shift @tmp;
    my($code,$url) = split;
    $code =~ s|library-||;
    $code =~ s|\.html$||;
    $code = uc($code);
    $URL{$code}=$url;
}

# -- backup der lokalen version
my $bak = $helpfile .'.' .strftime("%Y%m%d",localtime) .$Sigel;
unless ( -f $bak ) {
    print "* backup old files\n";
    File::Copy::copy($helpfile,$bak);
}

# -- neue version schreiben
print "* writing help-ccllib.html\n";
my $text = '';
my $skip = 0;
my $BASEL = select_codes('A', 'Basel');
my $BERN  = select_codes('B', 'Bern');
my $FHS = select_codes('F', 'Fachhochschulen online');
my $today = strftime("%e.%m.%Y", localtime);
open(F,"<$helpfile") or die "cannot read $helpfile: $!";
while ( <F> ) {
    if ( /<!-- start libbs/ ) {
        $text .= $_;
        $text .= $BASEL;
        $skip = 1;
        next;
    }
    if ( /<!-- start libbe/ ) {
        $text .= $_;
        $text .= $BERN;
        $skip = 1;
        next;
    }
    if ( /<!-- start fhch-fhbe/ ) {
        $text .= $_;
        $text .= $FHS;
        $skip = 1;
        next;
    }
    if ( /<!-- end/ ) {
        $skip = 0;
    }
    if ( /<!-- timestamp/ ) {
        $text .= '<!-- timestamp -->' .strftime("%e.%m.%Y",localtime) ."\n";
        next;
    }
    next if ( $skip );
    $text .= $_;
}
close F;
open(F, ">$helpfile") or die "cannot write $helpfile: $!";
print F $text;
close F;

# -- lokale version auf PROD server kopieren
print "* copy file to PROD host\n";
system "scp -q $helpfile aleph\@aleph.unibas.ch:$helpfile";
print "* done.\n";


sub select_codes {
    my $pattern = shift;
    my $wo = shift;
    my $rightcol=1;
    my $style='tdForm';     # tdForm = farbig, text1 = weiss
    my $ret = '';
    foreach my $code (sort (keys %sublibs) ) {
        next if ( $code !~ /^$pattern/ );
        next if ( $ignore{$code} );
        my $bez = HTML::Entities::encode($sublibs{$code});
        my $url = $URL{$code};
        if ( $url ) {
            $bez = qq|<a href="$url">$bez</a>|;
        }
        else {
            warn "ACHTUNG: keine Bibliotheksinfo fuer $code\n";
        }
        if ( $rightcol ) {
            $rightcol=0;
            $style = ( $style eq 'tdForm' ) ? 'text1' : 'tdForm';
            $ret .= qq|<tr class="$style">\n<td>$code</td><td>$bez</td>\n|;
        }
        else {
            $rightcol=1;
            $ret .= qq|<td>$code</td><td>$bez</td>\n</tr>\n|;
        }
    }
    # -- letzte Zeile
    if ( ! $rightcol ) {
        $ret .= qq|<td>&nbsp;</td><td>&nbsp;</td></tr>\n|;
    }
    # -- Schluss Tabelle farbig abschliessen
    if ( $pattern eq 'B' and $style eq 'text1' ) {
        $ret .= qq|<tr class="tdForm"><td colspan="4">&nbsp;</td></tr>\n|;
    }
    $ret;
}
