#!/usr/bin/perl

# make-tab40.pl

# - holt die tab40.<lng> vom Host
# - generiert den Abschnitt fuer die Collectioncodes aus dem MASTER file
# - macht ein Backup der Originaldatei
# - kopiert die neue Version auf den Server
# - loescht die UTF-Version der Originaldatei

# history
# - 09.09.1999: v.1/ava
# - 29.12.2004: portiert auf Aleph-V16, MSWin32 und Solaris
#   Anmerkung: die Struktur der tab40 ist in V14 und V16 identisch)
# - 14.09.2005: V14 herausgenommen (blu).
# - 14.10.2005: DST-Libraries herausgenommen (blu).
# - 06.12.2007: alephneua, V18 (ava)
# - 24.05.2010: V20 (blu)
# - 04.04.2013: V21 (blu)
# - 28.05.2014: V22 (blu), Code fuer multiple Versionen verbessert/ava
# - 27.04.2018: Anpassungen fuer virtuelle Umgebung unter RedHat/fbo

use strict;
use File::Copy;
use Net::Domain;
use POSIX qw(strftime);
$|=1;

my $MASTER      = 'masterfile.txt';
my $PROD        = 'aleph.unibas.ch';
my $TEST        = 'alephtest.unibas.ch';
my $BAK         = get_backup_extension('blu');   # .yyyymmdd + Sigel
my $TMPDIR      = 'tmp';
my $SCP         = 'scp -q';
my $SSH         = 'ssh';

my $ALEPH_VERSIONS = {
    'V22' => {
        hosts   => [ $PROD, $TEST ],
        user    => 'aleph',
        rootdir => '/exlibris/aleph/u22_1',
        utfdir  => '/tmp/utf_files',
        adm     => [ 'dsv51' ],
        lang    => [ 'ger', 'eng', 'fre' ],
    },

# Falls verschiedene Versionen, eigene Definition Prod u. Test:
#    'V22' => {
#        hosts   => [ $TEST ],
#        user    => 'aleph',
#        rootdir => '/exlibris/aleph/u22_1',
#        utfdir  => '/tmp/utf_files',
#        adm     => [ 'dsv51' ],
#        lang    => [ 'ger', 'eng', 'fre' ],
#    },
    
};

my $hostnames = {
    'ub-altest'  => $TEST,
    'ub-alprod'  => $PROD,
};
my $THIS_HOST = $hostnames->{Net::Domain::hostname};

my $List = generate_collection_list();

foreach my $version ( sort keys %$ALEPH_VERSIONS  ) {
    my $rec = $ALEPH_VERSIONS->{$version};
    my $cmd;
    foreach my $host ( @{$rec->{hosts}} ) {
        print "\nhost: $host\n";
        foreach my $adm ( @{$rec->{adm}} ) {
            foreach my $lang ( @{$rec->{lang}} ) {
                my $file = 'tab40.' . $lang;
                my $hostfile = "$rec->{rootdir}/$adm/tab/$file";
                my $localfile = "$TMPDIR/$file";

                print "* $hostfile\n";

                # --- download old file
                print "  download ";
                unlink $localfile;
                if ( $host eq $THIS_HOST ) {
                    File::Copy::copy($hostfile, $localfile);
                }
                else {
                    system "$SCP $rec->{user}\@$host:$hostfile $localfile";
                }
                ( -f $localfile ) or die "could not retrieve $localfile: $!";

                # -- write new file
                update_file($localfile, $adm);

                # -- backup old file
                print "- backup old version ";
                if ( $host eq $THIS_HOST ) {
                    unless ( -f "$hostfile.$BAK" ) {
                        # do not use File::Copy
                        system "cp -p $hostfile $hostfile.$BAK";
                    }
                }
                else {
                    $cmd = "if (! -f $hostfile.$BAK ) cp -p $hostfile $hostfile.$BAK";
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
                    $cmd = "if (-f $utf ) /bin/rm $utf";
                    exec_remote($cmd,$host,$rec);
                }
                print "- done.\n";
            }
        }
    }
}

sub exec_remote {

    # fuehre einen Befehl mit SSH aus.
    # (der Befehl muss in csh Syntax geschrieben sein)

    my($cmd,$host,$rec) = @_;
    if ( $^O eq 'MSWin32' ) {
        $cmd = "$SSH $rec->{user}\@$host $cmd";
    }
    else {
        $cmd = "$SSH $rec->{user}\@$host '$cmd'";
    }
    my $ret = `$cmd`;
    ( $? ) and print $ret, "\n";
}

sub update_file {

    # ersetzt den Abschnitt zwischen
    # !* === START
    # und 
    # !* === END
    # durch den DSV Teil der tab40-Liste

    my($file,$adm)=@_;
    local(*F,$_);
    my $skip = 0;
    my $new = '';
    my $datum = strftime("%Y-%m-%d %H:%M:%S",localtime);

    open(F, "<$file") or die "cannot read $file: $!";
    while ( <F> ) {
        if ( /^!\* === START / ) {
            $new .= $_
                 ."!* section generated with make-tab40.pl / $datum\n"
                 ."!* do not change manually\n";
            if ( $adm =~ /dsv/i ) {
                $new .= $List->{DSV};
            }
            else {
                die "which ADM ?!";
            }
            $skip = 1;
            next;
        }
        if ( /^!\* === END / ) {
            $skip = 0;
        }
        ( $new .= $_ ) unless ( $skip );
    }
    close F;

    open(F, ">$file" ) or die "cannot write $file: $!";
    binmode F;   # schreibt Datei im Unix-Format, auch unter MSWin32
    print F $new;
    close F;
}

sub generate_collection_list {

    # returns:
    #   eine HASHREF mit den Schluesseln 'DSV' mit
    #   den tab40-Listen fuer die produktiven und die Test-Libraries,
    #   generiert aus dem MASTER file

    local $_;
    my($ret,$sublib);
    $ret->{DSV}='';

    open(MASTER,"<$MASTER" ) or die "cannot read $MASTER: $!";
    while( <MASTER> ) {
        next if ( /^#/ );
        next if ( /^\s*$/ );
        chomp;
        s/\r//g;    # in case it's an MSWin32 file
        $_ = trim($_);
        if ( s/^SUBLIBRARY:\s*// ) {
            s/\s+(.*)$//;
            my $text = $1;
            $sublib = $_;
            $ret->{DSV} .= "\n!* ${sublib} - $text\n";
            next;
        }
        my $collection_code = uc(trim(substr($_,0,7)));
        my $collection_text = trim(substr($_,7));
        $ret->{DSV} .= sprintf("%-5.5s %-5.5s L %s\n", $collection_code, ${sublib}, $collection_text );

    }
    close MASTER;
    $ret;
}

sub get_backup_extension {
    my $sigel = shift || die "get_backup_extension: bitte Sigel angeben!";
    my ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    sprintf("%4.4d%2.2d%2.2d%s", $year + 1900, ++$mon, $mday, $sigel);
}

sub trim {
    local $_ = shift;
    s/^\s+//;
    s/\s+$//;
    $_;
}
