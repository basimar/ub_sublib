#!/usr/bin/perl -w
require 'masterfile.pl';

$OUTFILE = 'sublibs.txt';

$datum= localtime(time);
open(OUT,">$OUTFILE") or die "kann $OUTFILE nicht schreiben: $!";
print OUT<<EOD;
# Bibliothekscodes IDS Basel Bern
# produziert mit http://alephtest.unibas.ch/dirlist/u/local/sublib/sublibs.pl
#
# Stand: $datum
#
EOD
foreach my $key ( sort keys(%sublibs) ) {
    printf OUT ("%-7.7s %s\n", $key, $sublibs{$key} );
}
close OUT;
print "wrote $OUTFILE\n";
