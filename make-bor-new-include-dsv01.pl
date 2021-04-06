#!/usr/local/bin/perl -w
#
# schreibe Bibliotheksbezeichnungen in Neueinschreibungsformular Auswahllisten
# dsv01/www_f_lng/bor-new-include-dsv01
#
# history:
# 25.05.2016: Entwurf (bmt), Adaption von make-find-include-filter-bibl.pl 

use strict;
use vars qw( %sublibs );
use File::Copy;
use HTML::Entities;
use ava::sort::isolatin1;

my $User      = 'bmt';

# die folgenden Sublibraries sollen nicht in der Auswahl erscheinen. Meist handelt es sich um Zweigstellen, die kein eigene Benutzung anbieten, sondern nur als Magazin dienen.
my %ignore = map {$_=>1} (
    'A110',     # UB Stoer
    'A115',     # Basler Bibliographie 
    'A116',     # Basler Buchdruckerkatalog 
    'A126',     # UB Wirtschaft E-ZAS
    'A130',     # Bibliothek Altertum, UB Bestaende
    'A168',     # Bibliothek Altertum AS
    'B400',     # UB Speichermagazin 
    'B401',     # CD-Sammlung ZB 
    'B406',     # Bildungszentrum Pflege Online
    'B407',     # Zollikofen EHB Online 
    'B412',     # Berner Bibliographie
    'B450',     # Fliegende Katalogisierung BE
    'BSSBI',    # Speicherbibliothek
    'BSSBK',    # Speicherbibliothek
    'SOSBI',    # Speicherbibliothek
);

my $BaseDir   = '/exlibris/aleph/u22_1/dsv01';
my @lang      = qw( ger eng fre );
my $FileBase  = 'bor-new-include-dsv01';
my $Template  =  '<option value="%%CODE%%" $$2400-S"%%CODE%%">%%NAME%%</option>' . "\n";

# -- generate sorted lists of sublibraries
require "masterfile.pl";
my @basel;
my @bern;
foreach my $code ( keys %sublibs ) {
    next if ( $ignore{$code} );
    if ( $code =~ /^A/ ) {
        push(@basel, $sublibs{$code} . "\t" . $code);
    }
    elsif ( $code =~ /^B/ ) {
        push(@bern, $sublibs{$code} . "\t" . $code);
    }
}
@basel = sort isolatin1sort @basel;
@bern = sort isolatin1sort @bern;
my %Files;


my $BAK       = get_Backup_extension($User);
print STDERR "* aktualisiere lokale Dateien\n";
foreach my $lang ( @lang ) {
    reformat($lang);
}

print STDERR "* Befehle zum Kopieren auf den Produktionsserver:\n";
print <<EOD;
 ------------------------------
setenv aget $User
cd $BaseDir
EOD
foreach my $lang ( @lang ) {
    print "cd www_f_$lang\n";
    print "aput $FileBase\n";
    print "cd ..\n";
}
print <<EOD;
 ------------------------------
EOD

sub reformat {
    my $lang = shift;
    my $ALL = ( $lang eq 'ger' ) ? '[bitte ausw&auml;hlen]' :
              ( $lang eq 'eng' ) ? '[please select]' :
              ( $lang eq 'fre' ) ? '[choisissez s.v.p.]' : die 'jo was denn ???';

    local(*F,$_);

    # -- format selectbox options
    my $options = qq|<!-- filename: $FileBase -->\n|
        . qq|<select name=M_Z303_SUB_LIB>\n|
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

    $options .= qq|</select>\n|;

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
