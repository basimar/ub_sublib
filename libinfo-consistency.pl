#!/usr/bin/perl

# lininfo-consistency.pl
# 23.05.2012/ava
# 04.04.2013: V21/blu
# 28.05.2014: V22/blu

use strict;
use Data::Dumper;

print "aktualisiere sublibs.txt\n";
system "perl sublibs.pl";

my $sublibs;
open(IN,"<sublibs.txt") or die $!;
while ( <IN> ) {
    next if ( /^#/ );
    next if ( /^\s*$/ );
    next unless ( /^(A|B)/ );
    my($code,$desc)=/^(\w+)\s+(.*)$/;
    $sublibs->{$code}=$desc;
}
close IN;

my $libinfo;
open(IN,"<libinfo.txt") or die $!;
while ( <IN> ) {
    next if ( /^#/ );
    next if ( /^\s*$/ );
    my($code,$url)=split;
    $code =~ s/^.*-//;
    $code =~ s/\..*$//;
    $code = uc($code);
    $libinfo->{$code}=$url;
}
close IN;

print<<EOD;
------------------------------------------------------------------------
Bibliotheken aus der Verbunddatenbank ohne Libinfo
------------------------------------------------------------------------
EOD

foreach my $lib ( sort keys %$sublibs ) {
    unless ( $libinfo->{$lib} ) {
        print $lib, "\t", $sublibs->{$lib}, "\n";
    }
}

print<<EOD;
------------------------------------------------------------------------
Die folgenden Bibliotheken koennen aus der libinfo.txt geloescht werden,
ebenso die library-*.html in /exlibris/aleph/u22_1/dsv01/www_f_<lng>:
------------------------------------------------------------------------
EOD

foreach my $lib ( sort keys %$libinfo ) {
    unless ( $sublibs->{$lib} ) {
        print $lib, "\t", $libinfo->{$lib},  "\n";
    }
}


print<<EOD;
------------------------------------------------------------------------
EOD

