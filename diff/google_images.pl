use strict;
use lib qw[../lib];
use Parser::Google::Images;
use Data::Dumper;

my $images = new Parser::Google::Images();

print Dumper $images->get_results(q[компьютерные игры]);