#!/usr/bin/perl

sub usage {
    die<<'EOD';
Aktualisiert Aleph-Tabellen aus masterfile.txt.

Gebrauch:  make-tab-sublib.pl <option>

Optionen:
   -t    aktualisiert nur tab_sub_library.<lng>  (ALEPHE)  - fuer neue Bibliotheken und Ausleihe
   -c    aktualisiert nur check_doc_tag_text     (AUT/HOL) - fuer neue Bibliotheken (Plausibiltaeten)
   -o    aktualisiert nur tab_exp_own.<lng>      (ADM)     - fuer neue Bibliotheken (Berechtigungen)
   -a    aktualisert alles
   -h    help - zeigt diesen Text
   -n    no upload - generiert Dateien in ./tmp, macht aber keinen Upload

EOD
}

use strict;
use vars qw(%sublibs $ausleihcodes);
use File::Copy;
use Getopt::Std;
use Net::Domain;
use POSIX qw(strftime);
require 'masterfile.pl';
$|=1;

my $DEBUG   = 0;
my $PROD    = 'aleph.unibas.ch';
my $TEST    = 'alephtest.unibas.ch';
my $BAK     = get_backup_extension('blu');   # .yyyymmdd + Sigel
my $TMPDIR  = 'tmp';
my $SCP     = 'scp -q';
my $SSH     = 'ssh';

my $ALEPH_VERSIONS = {
    
    'V22' => {
        hosts   => [ $PROD, $TEST ],
        user    => 'aleph',
        rootdir => '/exlibris/aleph/u22_1',
        utfdir  => '/tmp/utf_files',
        aut     => [ 'dsv11', 'dsv12' ],
        bib     => [ 'dsv01' ],
        hol     => [ 'dsv61' ],
        adm     => [ 'dsv51' ],
        lang    => [ 'ger', 'eng', 'fre' ],
        langgui => [ 'ger', 'eng' ],
    },
    
# Falls verschiedenen Versionen, eigene Definition Test u. Prod:
#    'V22' => {
#        hosts   => [ $TEST ],
#        user    => 'aleph',
#        rootdir => '/exlibris/aleph/u22_1',
#        utfdir  => '/tmp/utf_files',
#        aut     => [ 'dsv11', 'dsv12' ],
#        bib     => [ 'dsv01' ],
#        hol     => [ 'dsv61' ],
#        adm     => [ 'dsv51' ],
#        lang    => [ 'ger', 'eng', 'fre' ],
#        langgui => [ 'ger', 'eng' ],
#    }

};

my $hostnames = {
    # 'hostname' des Rechners, gemappt auf DNS-Eintrag
    'ub-alprod' => $PROD,
    'ub-altest' => $TEST,
};

my %opts;
( @ARGV ) or usage;
getopts('achnot',\%opts) or usage;
$opts{h} and usage;
if ( $opts{a} ) {
    $opts{t}=1;
    $opts{c}=1;
    $opts{o}=1;
}
if ( $DEBUG ) {
    $opts{n}=1
};
my $THIS_HOST = $hostnames->{Net::Domain::hostname};
my $DATUM =  strftime("%Y-%m-%d %H:%M:%S",localtime);

my $Liste_sublib        = make_tab_sublib();
my $Liste_checkdoc_aut  = make_checkdoc_aut();
my $Liste_checkdoc_hol  = make_checkdoc_hol();
my $Liste_tab_exp_own   = make_tab_exp_own();

foreach my $key ( sort keys %$ALEPH_VERSIONS  ) {
    my $rec = $ALEPH_VERSIONS->{$key};
    my $cmd;
    foreach my $host ( @{$rec->{hosts}} ) {
        print "\nhost: $host\n";
        if ( $opts{t} ) {
            # -- tab_sub_library.<lng>
            foreach my $lang ( @{$rec->{lang}} ) {
                generate(
                    file    => "tab_sub_library.$lang",
                    hostdir => "alephe/tab",
                    liste   => $Liste_sublib,
                    host    => $host,
                    lib     => 'aleph',
                    rec     => $rec,
                );
            }
        }
        if ( $opts{c} ) {
            # --- AUT ---
            foreach my $lib ( @{$rec->{aut}} ) {
                generate(
                    file    => "check_doc_tag_text",
                    hostdir => "$lib/tab",
                    liste   => $Liste_checkdoc_aut,
                    host    => $host,
                    lib     => $lib,
                    rec     => $rec,
                );
            }
            # --- HOL ---
            foreach my $lib ( @{$rec->{hol}} ) {
                generate(
                    file    => "check_doc_tag_text",
                    hostdir => "$lib/tab",
                    liste   => $Liste_checkdoc_hol,
                    host    => $host,
                    lib     => $lib,
                    rec     => $rec,
                );
            }
        }
        if ( $opts{o} ) {
            # -- tab_exp_own.<lng>
            foreach my $lib ( @{$rec->{adm}} ) {
              foreach my $lang ( @{$rec->{langgui}} ) {
                generate(
                    file    => "tab_exp_own.$lang",
                    hostdir => "$lib/tab",
                    liste   => $Liste_tab_exp_own,
                    host    => $host,
                    lib     => $lib,
                    rec     => $rec,
                );
              }
            }
        }

    }
}
sub generate {
    my %p=@_;
    my $file    = $p{file}      || die;
    my $hostdir = $p{hostdir}   || die;
    my $lib     = $p{lib}       || die;
    my $host    = $p{host}      || die;
    my $liste   = $p{liste}     || die;
    my $rec     = $p{rec}       || die;

    my $hostfile = "$rec->{rootdir}/$hostdir/$file";
    my $localfile = "$TMPDIR/$file";
    unless ( $lib eq 'aleph' ) {
        $localfile .= "-$lib";
    }
    print "* $hostfile\n";
    download($hostfile,$localfile,$host,$rec);
    update($localfile,$liste,$lib);
    upload($localfile,$hostfile,$host,$rec);
    print "- done.\n";
}

sub download {
    my($hostfile,$localfile,$host,$rec)=@_;
    print  "  download ";
    unlink $localfile;
    if ( $host eq $THIS_HOST ) {
        File::Copy::copy($hostfile, $localfile);
    }
    else {
        system "$SCP $rec->{user}\@$host:$hostfile $localfile";
    }
    ( -f $localfile ) or die "could not retrieve $localfile: $!";
}

sub update {
    # ersetzt den Abschnitt zwischen "START" und "END" durch neuen Text
    my($localfile,$list,$lib)=@_;
    local(*F,$_);
    my $skip = 0;
    my $new = '';
    open(F, "<$localfile") or die "cannot read $localfile: $!";
    while ( <F> ) {
        if ( /^!\* === START / ) {
            $new .= $_
                 ."!* section generated with make-tab-sublib.pl / $DATUM\n"
                 ."!* do not change manually\n";
            $new .= $list;
            $skip = 1;
            next;
        }
        if ( /^!\* === END / ) {
            $skip = 0;
        }
        ( $new .= $_ ) unless ( $skip );
    }
    close F;
    open(F, ">$localfile" ) or die "cannot write $localfile: $!";
    binmode F;   # schreibt Datei im Unix-Format, auch unter MSWin32
    print F $new;
    close F;
    print "- update ";
}

sub upload {
    my ($localfile,$hostfile,$host,$rec)=@_;

    if ( $opts{n} ) {
        print "- skipping upload ";
        return;
    }

    # -- backup old file
    print "- backup old version ";
    if ( $host eq $THIS_HOST ) {
        unless ( -f "$hostfile.$BAK" ) {
            # do not use File::Copy
            system "cp -p $hostfile $hostfile.$BAK";
        }
    }
    else {
        my $cmd = "if (! -f $hostfile.$BAK ) cp -p $hostfile $hostfile.$BAK";
        exec_remote($cmd,$host,$rec);
    }

    # -- upload new file
    print "- upload ";
    if ( $host eq $THIS_HOST ) {
        File::Copy::copy($localfile, $hostfile);
    }
    else {
        system "$SCP $localfile $rec->{user}\@$host:$hostfile";
    }

    # -- delete UTF version of host file (might be broken during upload)
    print "- delete UTF version ";
    my $utf = $rec->{utfdir} . $hostfile;
    if ( $host eq $THIS_HOST ) {
        unlink $utf;
    }
    else {
        my $cmd = "if (-f $utf ) /bin/rm $utf";
        exec_remote($cmd,$host,$rec);
    }
}

sub make_tab_sublib {
    my $ret = "!* ----------\n!* DSV51\n!* ----------\n";
    local $_;
    foreach my $sublib ( sort(keys %sublibs) ) {
        my $desc = $sublibs{$sublib};

        my $col6 = 'DSV51';
        my $col7 = $ausleihcodes->{$sublib}->{Typ_Faelligkeiten};
        my $col8 = $ausleihcodes->{$sublib}->{Typ_Oeffnungszeiten};
        my $col9 = '';
        my $col10 = '';

        if ( $ausleihcodes->{$sublib}->{Typ_Ausleihe} eq 'Verbund' ) {
            $col9=$sublib;
            $col10='DSV51';
        }
        elsif ( $ausleihcodes->{$sublib}->{Typ_Ausleihe} eq 'lokal' ) {
            $col9=$sublib;
        }

        # -- Extrawurst Gosteli
        if ( $sublib eq 'B402' ) {
            $col9 = 'B400';
        }

        $_ = sprintf( "%-5.5s 1 DSV51 L %-30.30s %-5.5s %-5.5s %-5.5s %-5.5s %s",
                $sublib, $desc, $col6, $col7, $col8, $col9, $col10);

        # -- Extrawurst A110, B450 (Stoerkatalogisierung = nur Kommentar)
        if ( $sublib eq 'A110' || $sublib eq 'B450' ) {
            $_ = sprintf("!* %-5.5s        %s", $sublib, $desc);
        }

        s/\s+$//;
        $ret .= "$_\n";
    }
    $ret;
}

sub make_checkdoc_aut {
    my $ret='';
    foreach my $lib ( sort keys %sublibs ) {
        $ret .= qq|040## L a SzZuIDS BS/BE ${lib}\n|;
    }
    $ret;
}

sub make_checkdoc_hol {
    my $ret='';
    foreach my $lib ( sort keys %sublibs ) {

        # Ausnahmen: St�rkatalogisierung
        next if ( $lib eq 'A110' );
        next if ( $lib eq 'B450' );

        $ret .= qq|OWN## L a ${lib}\n|;
    }
    $ret;
}

sub make_tab_exp_own {
    my $ret='';
    foreach my $lib ( sort keys %sublibs ) {
        if (length(${lib}) == 4) {
            $ret .= qq|${lib}                                               ${lib}\n|;
        } else {
            $ret .= qq|${lib}                                              ${lib}\n|;
        }
    }
    $ret;
}

sub get_backup_extension {
    my $sigel = shift || die "get_backup_extension: bitte Sigel angeben!";
    my ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    sprintf("%4.4d%2.2d%2.2d%s", $year + 1900, ++$mon, $mday, $sigel);
}

sub exec_remote {
    # fuehre einen Befehl mit SSH aus.
    # (der Befehl muss in csh Syntax geschrieben sein)
    my($cmd,$host,$rec) = @_;
    $cmd = "$SSH $rec->{user}\@$host '$cmd'";
    my $ret = `$cmd`;
    ( $? ) and print $ret, "\n";
}

__END__

=head1 NAME

make-tab-sublib.pl  - aktualisiert Aleph-Tabellen aus masterfile.txt

=head1 SYNOPSIS

 Gebrauch:  make-tab-sublib.pl <option>

 Optionen:
   -t    aktualisiert nur tab_sub_library.<lng>  (ALEPHE) - fuer neue Bibliotheken und Ausleihe
   -c    aktualisiert nur check_doc_tag_text     (AUT/BIB/HOL) - fuer neue Bibliotheken in 040
   -o    aktualisiert nur tab_exp_own.<lng>      (ADM) - fuer neue Bibliotheken-Berechtigungen
   -a    aktualisert alles
   -h    help - zeigt diesen Text
   -n    no upload - generiert Dateien in ./tmp, macht aber keinen Upload

=head1 DESCRIPTION

=over

=item *

holt Dateien vom Host (tab_sub_library.<lng> aus ALEPHE, check_doc_tag_text
aus AUT/BIB/HOL)

=item *

generiert fuer jedes File die entsprechenden Abschnitte aus dem Masterfile

=item *

macht ein Backup der Originaldateien auf dem Host

=item *

kopiert die neue Versionen auf den Server

=item *

loescht die UTF-Version der Originaldateien auf dem Server

=back

=head2 ALEPHE/tab_sub_library

 Default (keine Ausleihe):
 ------------------------

 ! 1   2   3   4             5                    6     7     8     9    10   11    12    13
 !!!!!-!-!!!!!-!-!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!-!!!!!-!!!!!-!!!!!-!!!!!-!!!!!-!!!!!-!!!!!-!!!!!
 A190  1 DSV51 L Basel Deutsches Seminar        DSV51

 Lokale Ausleihe:
 ----------------
 - Bibliothekscode in in Spalte 9

 ! 1   2   3   4             5                    6     7     8     9    10   11    12    13
 !!!!!-!-!!!!!-!-!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!-!!!!!-!!!!!-!!!!!-!!!!!-!!!!!-!!!!!-!!!!!-!!!!!
 A332  1 DSV51 L Basel Musik-Akademie           DSV51 IDS   A332  A332

 Verbund-Ausleihe:
 -----------------
 - Bibliothekscode in in Spalte 9
 - 'DSV51' in Spalte 10

 ! 1   2   3   4             5                    6     7     8     9    10   11    12    13
 !!!!!-!-!!!!!-!-!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!-!!!!!-!!!!!-!!!!!-!!!!!-!!!!!-!!!!!-!!!!!-!!!!!
 A198  1 DSV51 L Basel Geographisches Institut  DSV51 IBB   A198  A198  DSV51

 Ausnahmen:
 ----------
 A110  Stoerkatalogisierung. Nur Pro Memoria aufgenommen (auskommentiert)
 A125  eigene GroupID 'A125' statt DSV51
 B402  Spezialfall: Verbundausleihe, aber mit StUB Benutzer Record
 B450  Stoerkatalogisierung. Nur Pro Memoria aufgenommen (auskommentiert)

=head2 AUT/check_doc_tag_text

 040## L a SzZuIDS BS/BE A100

=head2 BIB/check_doc_tag_text

Seit 1.01.2010 wird das Feld 040 in check_doc_tag nicht mehr geprueft.
Siehe http://www.ub.unibas.ch/babette/index.php/News:2010-01-04

=head2 HOL/check_doc_tag_text

 OWN## L a A100

=head2 ADM/tab_exp_own.<lng>

 A100                                               A100
 A110                                               A110
 A125                                               A125
 A140                                               A140

=head1 HISTORY

 09.03.1999: v1
 30.12.2004: rewrite fuer parallele Mutation V14/V16, MSWin32 und Solaris
             Anmerkung: die Struktur aller Tabellen ist identisch in V14 und V16
             V14 herausgenommen (blu)
 14.10.2005: DST-Libraries herausgenommen (blu)
 04.08.2006: Generierung von tab_exp_own.<lng> ergaenzt (blu)
 27.11.2007: V18: allg. Anpassungen (blu)
 27.11.2007: Kein ALEPH-Zweigstellenprofil mehr in Spalte 11 tab_sub_library.lng f. Verbundausleihe (blu)
 06.12.2007: Win32-Code entfernt, Option no upload, exaktere Hosterkennung (ava)
 06.04.2008: Aenderungen fuer neues Ausleihmodell IDS (ava)
 26.03.2009: Fehler bzw. Anachronismus in make_checkdoc_hol() korrigiert (blu)
 12.08.2009: Extrawurst A125 entfernt
 17.12.2010: 040 in check_doc_tag der BIB wird nicht mehr geprueft
             siehe http://www.ub.unibas.ch/babette/index.php/News:2010-01-04
 04.04.2013: V21/blu
 28.05.2014: V22/blu -- Code fuer multiple Versionen verbessert/ava
 
=head1 AUTHOR

andres.vonarx@unibas.ch, bernd.luchner@unibas.ch

=cut

