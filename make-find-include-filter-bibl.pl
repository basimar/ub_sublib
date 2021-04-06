#!/usr/local/bin/perl -w
#
# schreibe Bibliotheksbezeichnungen in Opac Auswahllisten
# dsv01/www_f_lng/find-include-filter-bibl
#
# history:
# 01.08.2004: Aleph 14.2.08 frameless
# 16.11.2005: rev. fuer Aleph 16.2
# 07.12.2007: Aleph 16 (ava)
# 07.01.2008: Aleph 18 (blu)
# 24.05.2010: Aleph 20 (blu)
# 04.04.2013: Aleph 21 (blu)
# 22.04.2013: FHs (blu)
# 28.05.2014: Aleph 22 (blu)
# 18.03.2018: Kopiert Files automatisch auf produktiven Server (bmt)
# 22.05.2018: Ausnahme fÃr Code A149

use strict;
use vars qw( %sublibs );
use File::Copy;
use HTML::Entities;
use ava::sort::isolatin1;

my $User      = 'blu';

# die folgenden Sublibraries sollen nicht in der Auswahl erscheinen
my %ignore = map {$_=>1} (
    'A110',     # UB Stoer
    'A149',     # UB Speibi Kassationsbestand
    'B450',     # Fliegende Katalogisierung BE
);

my $BaseDir   = '/exlibris/aleph/u22_1/dsv01';
my @lang      = qw( ger eng fre );
my $FileBase  = 'find-include-filter-bibl';
my $Template  =  '<option value="%%CODE%%" $$7000-S"%%CODE%%">%%NAME%%</option>' . "\n";

# -- generate sorted lists of sublibraries
require "masterfile.pl";
my @basel;
my @bern;
my @fhs;
foreach my $code ( keys %sublibs ) {
    next if ( $ignore{$code} );
    if ( $code =~ /^A/ ) {
        push(@basel, $sublibs{$code} . "\t" . $code);
    }
    elsif ( $code =~ /^B/ ) {
        push(@bern, $sublibs{$code} . "\t" . $code);
    }
    elsif ( $code =~ /^F/ ) {
        push(@fhs, $sublibs{$code} . "\t" . $code);
    }
}
@basel = sort isolatin1sort @basel;
@bern = sort isolatin1sort @bern;
@fhs = sort isolatin1sort @fhs;
my %Files;


my $BAK       = get_Backup_extension($User);
print STDERR "* aktualisiere lokale Dateien\n";
foreach my $lang ( @lang ) {
    reformat($lang);
}

# -- lokale version auf PROD server kopieren
print "* copy file to PROD host\n";
$ENV{aget} = "blu";
for my $lang (@lang) {
    system "cd $BaseDir/www_f_$lang/\naput $FileBase";
}
print "* done.\n";


sub reformat {
    my $lang = shift;
    my $ALL = ( $lang eq 'ger' ) ? 'alle' :
              ( $lang eq 'eng' ) ? 'all' :
              ( $lang eq 'fre' ) ? 'Toutes' : die 'ja watt denn ???';

    local(*F,$_);

    # -- format selectbox options
    my $options = qq|<!-- filename: $FileBase -->\n|
        . qq|<option value="">$ALL</option>\n|
        . qq|<option value="">---- Basel: -----------</option>\n|;
    foreach my $lib ( @basel ) {
        my($name,$code) = split /\t/, $lib;
        $name = HTML::Entities::encode($name);
        $_ = $Template;
        s|%%NAME%%|$name|g;
        s|%%CODE%%|$code|g;
        $options .= $_;
    }
    $options .= qq|<option value="">---- Bern: ------------</option>\n|;
    foreach my $lib ( @bern ) {
        my($name,$code) = split /\t/, $lib;
        $name = HTML::Entities::encode($name);
        $_ = $Template;
        s|%%NAME%%|$name|g;
        s|%%CODE%%|$code|g;
        $options .= $_;
    }
    $options .= qq|<option value="">---- Fachhochschulen online: ----</option>\n|;
    foreach my $lib ( @fhs ) {
        my($name,$code) = split /\t/, $lib;
        $name = HTML::Entities::encode($name);
        $_ = $Template;
        s|%%NAME%%|$name|g;
        s|%%CODE%%|$code|g;
        $options .= $_;
    }


    my $file = "$BaseDir/www_f_$lang/$FileBase";
    print STDERR "$lang: $FileBase\n";

    # -- backup local file;
    my $backup = "$file.$BAK";
    ( -f $backup ) or File::Copy::copy($file, $backup);

    # -- write new file
    open(F, ">$file") or die "cannot read $file: $!";
    print F $options;
    close F;

}

sub get_Backup_extension {
    my $sigel=shift;
    my ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    sprintf("%4.4d%2.2d%2.2d%s", $year + 1900, ++$mon, $mday, $sigel);
}
