#!/usr/bin/perl -w
package Parser::Google::Images;
use strict;
use warnings;

use WWW::Curl::Easy;
use Digest::MD5 qw[md5_hex];
use Carp qw[croak];
use URI::Escape;
use lib qw[../../];
use Jum::Logger;
use Jum::Web::Crawler;


use Data::Dumper;

our $VERSION = '0.01';

sub new {
    my ($self, $params) = @_;

    $self = {};

    # Доменные зоны, в которых мы будем искать
    $self->{zone}           =   [];

    # Запрос, который будет искаться
    $self->{query}          =   undef;

    # Безопасный поиск
    $self->{safesearch}     =   q[on];

    if($params && ref $params eq q[HASH]){
        #
    }

    # допилить исключения
    $self->{exceptions} = {
        q[http://gravatar.com] => undef
    };

    $self->{href}  =   q[http://www.google.com/images?];
    $self->{href}  .=  q[um=1];
    $self->{href}  .=  q[&hl=ru];
    $self->{href}  .=  q[&gbv=2];
    $self->{href}  .=  q[&prmdo=1];
    $self->{href}  .=  q[&as_st=y];
    $self->{href}  .=  q[&tbs=isch%3A1];
    $self->{href}  .=  q[&sa=1];
    $self->{href}  .=  q[&q=%query%];
    $self->{href}  .=  q[&aq=f];
    $self->{href}  .=  q[&aqi=g10];
    $self->{href}  .=  q[&aql=];
    $self->{href}  .=  q[&oq=];
    $self->{href}  .=  q[&gs_rfai=];
    $self->{href}  .=  q[&biw=640];
    $self->{href}  .=  q[&bih=480];
    $self->{href}  .=  q[&addh=36];
    $self->{href}  .=  q[&ijn=bg];
    $self->{href}  .=  q[&safe=%safesearch%];
    $self->{href}  .=  q[&as_sitesearch=%zone%];

    $self->{href}  .=  q[&page=%page%];
    $self->{href}  .=  q[&start=%start%];

    # Агенты, которые гугл считает более трастовыми
    $self->{ua_list}    = [
        'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) AppleWebKit/525.19 (KHTML, like Gecko) Chrome/1.0.154.48 Safari/525.19',
        'Mozilla/5.0 (Windows; U; Windows NT 5.1; ru; rv:1.9.0.11) Gecko/2009060215 Firefox/3.0.11',
        'Mozilla/5.0 (Windows; U; Windows NT 5.1; ru; rv:1.9.0.1) Gecko/2008070208 Firefox/3.0.1',
        'Mozilla/5.0 (Windows; U; Windows NT 6.0; en-US; rv:1.9.0.9) Gecko/2009040821 Firefox/3.0.9 (.NET CLR 3.5.30729)',
        'Mozilla/5.0 (Windows; U; Windows NT 6.0; ru; rv:1.9.0.6) Gecko/2009011913 Firefox/3.0.6 (.NET CLR 3.5.30729)',
        'Mozilla/5.0 (Windows; U; Windows NT 6.0; ru; rv:1.9.1) Gecko/20090624 Firefox/3.5 (.NET CLR 3.5.30729)'
    ];

    bless($self);
    return $self;
}

sub get_results {
    my ($self, $query, $params) = @_;

    return undef unless $query;


    $query      =   uri_escape $query;

    my $href    =   $self->{href};
    my $zone    =   join(' ', @{$self->{zone}});
    $href =~ s/%query%/$query/;
    $href =~ s/%safesearch%/$self->{safesearch}/;

    $href =~ s/%zone%/$zone/;


    $params = {} unless ref $params eq q[HASH];
    $params->{ag} = undef unless exists $params->{ag};
    $params->{page} = 0 unless $params->{page};
    $params->{page} = 0 unless $params->{page} =~ /^\d+$/;
    my $start = $params->{page}*25;
    $href =~ s/%start%/$start/;

    $href =~ s/%page%/$params->{page}/;

    print $href."\n";
    my $ag = $self->{ua_list}->[rand(@{$self->{ua_list}})];
    my $result  =   Jum::Web::Crawler::getURL({
                                            href    =>  $href,
                                            ag      =>  $ag
                                    });

    my $results = [];
    if($result->{retcode} == 0 && $result->{http_code} == 200){
        while($result->{content} =~ /href="([^"]+)/isg){
            my $addHref= $1;
            $addHref =~ s/&amp;/&/g;
            my $addResult = Jum::Web::Crawler::getURL({href=>q[http://google.com].$addHref, ag=>$ag, referer=>$href});
            if($addResult->{retcode} == 0 && $result->{http_code} == 200){
                if($addResult->{content} =~ /function\(\)\{x\(\)\}\);m\.src=decodeURIComponent\('([^']+)'\)/i){
                    my $image = $1;
                    $image = uri_unescape($image);
                    print qq[Got $image\n];
                    push(@$results, $image);
                }
            }
        }
    }
    else{
        Jum::Logger::error(q[Bad result on quering ].uri_unescape($query)." $result->{retcode} $result->{http_code}");
    }
    return $results;
}


1;