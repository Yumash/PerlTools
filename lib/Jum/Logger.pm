#!/usr/bin/perl -w
package Jum::Logger;

use strict;
use Term::ANSIColor;

=pod
Простой логгер для цветного вывода ситуации в консоли. Удобно при работе с "длинными" скриптами.
Я уже не помню почему, но мне не очень понравился Log4perl - хотелось чего-то более яркого и понятного, для выцепления информации в потоке.
=cut

our $colors = {
                'o'   =>  q[green],
                'e'   =>  q[red],
                'n'   =>  q[yellow]
            };
sub notice {
    m_send('n', @_);
}

sub ok {
    m_send('o', @_);
}

sub error {
    m_send('e', @_);
}

sub m_send {
    my ($type, $message) = @_;
    if($message){
        my $date = getDate();
        print $date->{hour}.q[:].$date->{min}.q[:].$date->{sec}.qq[ ];
        print color $colors->{$type};
        print q[ \[].uc($type)."] ";
        print color 'reset';
        print " ".$message."\n";
    }
}

sub getDate {
    my $shift = shift;
    my $t = time;
    if($shift && $shift=~/^\d+$/){
        $t = time-$shift;
    }
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($t);
    $sec    = q[0].$sec     if length $sec  == 1;
    $min    = q[0].$min     if length $min  == 1;
    $hour   = q[0].$hour    if length $hour == 1;
    
    my %time;
    
    $time{day}  = $mday;
    $time{mon}  = $mon+1;
    $time{year} = $year+1900;
    $time{hour} = $hour;
    $time{min}  = $min;
    $time{sec}  = $sec;
    
    return \%time;
}