#!/usr/bin/perl -w
package Jum::DB;
use strict;
use warnings;
use DBI;
=head1 Список соединений с БД

=cut

our %db_data;

$db_data{nowow}             =   {
                                    login       =>  q[jum_sites],
                                    password    =>  q[DNh8HAB8px7d4Gsh],
                                    db          =>  q[jum_nowow_ru]
                                };

$db_data{sofoxy}            =   {
                                    login       =>  q[jum_sites],
                                    password    =>  q[DNh8HAB8px7d4Gsh],
                                    db          =>  q[jum_sofoxy_ru]
                                };

$db_data{kinozentr}         =   {
                                    login       =>  q[jum_sites],
                                    password    =>  q[DNh8HAB8px7d4Gsh],
                                    db          =>  q[jum_kinozentr_ru]
                                };

$db_data{gold}              =   {
                                    login       =>  q[jum_sites],
                                    password    =>  q[DNh8HAB8px7d4Gsh],
                                    db          =>  q[jum_gold]
                                };

$db_data{carsupplies}       =   {
                                    login       =>  q[jum_sites],
                                    password    =>  q[DNh8HAB8px7d4Gsh],
                                    db          =>  q[jum_carsupplies_ru]
                                };
$db_data{shleiko_audio}      =   {
                                    login       =>  q[jum_sites],
                                    password    =>  q[DNh8HAB8px7d4Gsh],
                                    db          =>  q[jum_freelance_shleiko_audio]
                                };

$db_data{jumshop_ru}        =   {
                                    login       =>  q[jum_jumshop_ru],
                                    password    =>  q[zU8phbFVZBnv26DW],
                                    db          =>  q[jum_jumshop_ru]
                                };

$db_data{qska_net}          =   {
                                    login       =>  q[jum_sites],
                                    password    =>  q[DNh8HAB8px7d4Gsh],
                                    db          =>  q[jum_qska_net]
                                };

sub connect{
    my ($config, $type) = @_;

    return undef unless exists $db_data{$config};

    $type = $type ? {'AutoCommit' => 0, 'PrintError'=>1} : {'AutoCommit' => 1, 'PrintError'=>1};

    my @connstring  =   (
                        q[DBI:mysql:database=].$db_data{$config}->{db}.q[;host=localhost;port=3306],
                        $db_data{$config}->{login},
                        $db_data{$config}->{password},
                        $type
                    );
    my $dbh = eval{DBI->connect(@connstring)};
    my $i = 0;
    while (!defined($dbh)){
        last if $i>10;
        sleep(2);
        $dbh = eval{DBI->connect(@connstring)};
        print $! if $!;
        $i++;
    }
    print $! if $!;
    $dbh->do(qq[SET CHARSET UTF8]);
    if($dbh->errstr){
        sleep(2);
        return db_connect(@connstring);
    }
    return $dbh;
}

1;
