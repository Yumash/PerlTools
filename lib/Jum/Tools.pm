#!/usr/bin/perl -w
package Jum::Tools;
use strict;
use warnings;

=head1 Общие функции

=cut

sub isStarted {
    my $processName = shift;
    return undef unless $processName;
    return undef unless $processName =~ /^[\w\s]+$/i;
    return 1 if length qx/ps axf | grep '$processName' | grep -v 'grep'/ > 0;
    return undef;
}


1;