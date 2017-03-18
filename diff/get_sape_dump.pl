#!/usr/bin/perl -w
use strict;
use lib qw[../lib];
use Jum::DB;


my $href            =   q[http://e.sape.ru/];
my $filename        =   q[supersecretlink.txt.bz2];
my $local_filename  =   q[supersecretlink.txt];
#`wget $href$filename`;
#`bunzip2 $filename`;

my $dbh = Jum::DB::connect(q[sape]);
#http://www.vvv.ru/
#3
#1
#9
#2200.00
#68620208
#107
#3500
#1
#1
#0
#1
#1
#2010-12-21      1997-08-10      1073
my $insert_domain_query = q[
                INSERT IGNORE donor_domain
                SET
                    domain_sape_id = ?,
                    domain_name = ?,
                    domain_name_md5 = MD5(?)
            ];

my $get_domain_id_query =   q[
    SELECT domain_id FROM donor_domain WHERE domain_name_md5 = MD5(?)
];

my $insert_page_query   =   q[
                INSERT INTO donor_page SET
                    page_href = ?,
                    page_href_md5 = MD5(?),
                    page_indexed = ?,
                    page_index_date = ?,
                    f_domain_id = ?,
                    page_sape_id = ?
                ON DUPLICATE KEY UPDATE
                    page_indexed = ?,
                    page_index_date = ?
            ];
open FF,"<$local_filename";
while(<FF>){
    next if $_ !~ /5ft\.ru/;
    my ($domain, $page, $date) = ($1,$2, $3) if $_ =~ /^http:\/\/([^\/]+)\/([^\t]*)\t(?:[^\t]+\t){12}([^\t]+)/;
    my $domain_id = get_domain_id(\$domain);
    if(!$domain_id){
        $dbh->do($insert_domain_query, undef, $domain, $domain);
        $domain_id = get_domain_id(\$domain);
    }
    $dbh->do($insert_page_query,
                undef,
                $page,
                $page,
                ($date eq '0000-00-00' ? 'no' : 'yes'),
                $date,
                $domain_id,
                ($date eq '0000-00-00' ? 'no' : 'yes'),
                $date
    );
}
close FF;

sub get_domain_id {
    my $name = shift;
    return $dbh->selectrow_array($get_domain_id_query, undef, $$name);
}