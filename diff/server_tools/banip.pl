#!/usr/bin/perl -w
use strict;

unless($ARGV[0]){
    print qq[Usage:\n\t\tbanip <IP>\n\t\tbanip <FILE WITH IP>\n\n];
    exit;
}

if($ARGV[0] =~ /^(\d{1,3}\.){3}\d{1,3}$/){
    open FF,">>/root/bad_ips.txt";
    print FF $ARGV[0]."\n";
    close FF;
    `iptables -A INPUT -s $ARGV[0] -j DROP`;
    print qq[OK\n];
}
else{
    my $i = 0;
    if(-e $ARGV[0]){
        open FF,"<".$ARGV[0];
        while(<FF>){
            chop $_;
            if($_ =~ /^(\d{1,3}\.){3}\d{1,3}$/){
                `iptables -A INPUT -s $_ -j DROP`;
                $i++;
            }
        }
        close FF;
        print qq[OK $i IPs\n];
    }
    else{
        print qq[No such file\n];
    }
}