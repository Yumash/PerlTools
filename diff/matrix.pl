#!/usr/bin/perl -w
use strict;
use Term::ANSIColor;
use Time::HiRes qw[usleep];

if (defined ($ARGV[0]) && $ARGV[0]!~/^\d+$/){
    print color 'reset';
    exit;
}
my $num = 1000000;  # сколько раз крутить
my $strlen = 120;    # длина строки
my $length = 10000; # чем больше — тем дольше будет «вычисляться» строка

if($#ARGV != -1){
    $num = $ARGV[0] if $ARGV[0] =~ /^\d+$/;
    $strlen = $ARGV[1] if $ARGV[1] =~ /^\d+$/;
    $length = $ARGV[2] if $ARGV[2] =~ /^\d+$/;
}

my ($stop, %matrix) = (0, undef);

my @a = ('a'...'z', 'A'...'Z', 0...9);

for (0...$num){
    for (0...$strlen){
        my $s = $a[int(rand($#a+1))];
        print color 'bold green';
        if (exists ($matrix{$_})){
            print color 'clear green';
            print $matrix{$_};
        }
        else{
            print $s;
            $matrix{$_} = $s if (int (rand ($length)) == ($length-1));
        }
        print color 'reset';
    }
    usleep (rand (10000)+10000);
    print "\n";
    last if $stop > 0;
    $stop ++ if scalar keys %matrix == ($strlen+1);
}

print color 'reset';