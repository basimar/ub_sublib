# masterfile.pl
# - parst den Inhalt von 'masterfile.txt' in globale HASHes
# - prueft die max. Laenge der Bezeichnung der Sublibs
# - optional: prueft die Eindeutigkeit der Bezeichnungen der Collections
# - aktualisert die HTML-Version 'masterfile.html'
#
# %sublibs
#   key:    sublib code, z.B. 'A100'
#   value:  Bezeichnung, z.B. 'BS UB'
#
# %collections
#   key:    collection code, z.B. 'MAG'
#   value:  Bezeichnung, z.B. 'Magazin'
#
# $ausleihcodes  (hashref)
#   key:    sublib code, z.B. 'A100'
#   subkeys & values:
#       Typ_Ausleihe          (keine/Verbund/lokal)
#       Typ_Faelligkeiten     (tab16 / tab_sub_lib col 7)
#       Typ_Oeffnungszeiten   (tab17 / tab_sub_lib col 8)
#
# history;
# - 09.09.1999 andres.vonarx@unibas.ch
# - 08.02.2008 rev.: 'ausleihcodes' ergaenzt
# - 17.12.2010 masterfile.html (fuer korrekten Zeichensatz in dirlist)
# - 28.05.2014 akzeptiert dublette collection codes

use strict;
use ava::utf::ansi2utf;
use vars qw ( %sublibs %collections $ausleihcodes);
no warnings "uninitialized";

local($_,*IN,*OUT);

my $masterfile      = "masterfile.txt";
my $masterfile_html = "masterfile.html";
my $maxlen_sublib   = 30;
my $max_templ       = '----+----|----+----|----+----|';
my $Do_Check_Unique_Collection_Codes = 0;
my $sublib_code;
my $ansi2utf = ava::utf::ansi2utf->new();
open(IN, "<$masterfile" ) or die "cannot read $masterfile: $!";
while( <IN> ) {
    if ( /^#/ ) {
        if ( s/^# Aleph-Ausleihe:// ) {
            chomp;
            my @tmp = split /\s*\|.*?:\s*/;
            $ausleihcodes->{$sublib_code}->{Typ_Ausleihe} = trim($tmp[0]);
            $ausleihcodes->{$sublib_code}->{Typ_Faelligkeiten} = trim($tmp[1]);
            $ausleihcodes->{$sublib_code}->{Typ_Oeffnungszeiten} = trim($tmp[2]);
        }
        next;
    }
    next if ( /^\s*$/ );
    s/\r//g;    # in case it's an MSWin32 file
    chomp;

    # sublibraries
    if ( s/^SUBLIBRARY:\s*// ) {
        s/^(\S+)\s+//;
        $sublib_code = $1;
        my $sublib_text = trim($_);
        check_sublib_length($sublib_text, $sublib_code);
        $sublibs{ $sublib_code } = $sublib_text;
    }
    # collections
    else {
        my $collection_code = trim( substr( $_, 0, 7));
        my $collection_text = substr( $_, 7);
        if ( $collections{$collection_code} and $Do_Check_Unique_Collection_Codes ) {
            if ( $collections{$collection_code} ne $collection_text ) {
                print STDERR<<EOD;
WARNUNG!
Fuer $collection_code sind zwei Bezeichnungen definiert:
$collections{$collection_code}
$collection_text
EOD
#               exit;
            }
        }
        $collections{$collection_code} = $collection_text;
    }
}
close IN;

sub trim {
    local( $_ )=shift;
    s/^\s*//;
    s/\s*$//;
    $_;
}

sub check_sublib_length {
    my $ansi=shift;
    my $code=shift;
    my $utf = $ansi2utf->convert($ansi);
    if ( length($utf) > $maxlen_sublib ) {
        die "\aACHTUNG: $code\n$max_templ\n$utf\n\n";
    }
}

# schreibe UTF-8 Version als HTML
open(IN, '<:encoding(latin1)', $masterfile)
    or die "cannot read $masterfile: $!";
open(OUT,'>:encoding(utf8)',   $masterfile_html)
    or die "cannot write $masterfile_html: $!";
print OUT <<EOD;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<title>IDS Basel Bern: Aleph Bibliothekcodes und Standortcodes</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
</head>
<body>
<pre>
EOD

while ( <IN> ) {
    print OUT $_;
}
close IN;
close OUT;

1;
