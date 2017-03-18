#!/usr/bin/perl -w
package Parser::MailRu::Auto;
use strict;
use warnings;

use Digest::MD5 qw[md5_hex];
use Carp qw[croak];
use URI::Escape;
use lib qw[../../];
use Jum::Logger;
use Jum::Web::Crawler;
use Text::Iconv;
use Jum::Text;

use Data::Dumper;

our $VERSION = '0.01';

#http://auto.mail.ru/market/found.html?order_by=&direction=&last_offers=&new_old_type=&is_foreign=&firm_id=&model_id=&body_type=&price_min=0&price_max=5000000&price_type=192&year_min=1970&year_max=2010&engine_volume_min=0&engine_volume_max=8000&run_min=0&run_max=Infinity&run_type=200&auto_condition=186%2C187%2C188%2C189%2C190%2C191&gear_type=&wheel_gear=85%2C87%2Cfull&steer_position=&photo_exists=1&seller_type=&date_range=&country=24&region=25&city=25&page=28

sub new {
    my ($self, $params) = @_;
    $params = {} unless $params;
    return undef unless ref $params eq q[HASH];

    $self = {};
    $self->{href_prefix}    =   q[http://auto.mail.ru];
    $self->{href}   =   $self->{href_prefix}.q[/market/found.html?];
    $self->{href}   .=  q[order_by=];
    $self->{href}   .=  q[&direction=];
    $self->{href}   .=  q[&last_offers=];
    $self->{href}   .=  q[&new_old_type=];
    $self->{href}   .=  q[&is_foreign=];
    $self->{href}   .=  q[&firm_id=];
    $self->{href}   .=  q[&model_id=];
    $self->{href}   .=  q[&body_type=];

    $self->{href}   .=  (exists $params->{price_min} && $params->{price_min} && $params->{price_min} =~ /^\d+$/) ?
                        q[&price_min=].$params->{price_min} : q[&price_min=0];

    $self->{href}   .=  (exists $params->{price_max} && $params->{price_max} && $params->{price_max} =~ /^\d+$/) ?
                        q[&price_max=].$params->{price_max} : q[&price_max=5000000];

    $self->{href}   .=  q[&price_type=192];

    $self->{href}   .=  (exists $params->{year_min} && $params->{year_min} && $params->{year_min} =~ /^\d{4}$/) ?
                        q[&year_min=].$params->{year_min} : q[&year_min=1970];

    $self->{href}   .=  (exists $params->{year_max} && $params->{year_max} && $params->{year_max} =~ /^\d{4}$/) ?
                        q[&year_max=].$params->{year_max} : q[&year_max=2010];

    $self->{href}   .=  (exists $params->{engine_min} && $params->{engine_min} && $params->{engine_min} =~ /^\d+$/) ?
                        q[&engine_volume_min=].$params->{engine_min} : q[&engine_volume_min=0];

    $self->{href}   .=  (exists $params->{engine_max} && $params->{engine_max} && $params->{engine_max} =~ /^\d+$/) ?
                        q[&engine_volume_max=].$params->{engine_max} : q[&engine_volume_max=0];

    $self->{href}   .=  (exists $params->{run_min} && $params->{run_min} && $params->{run_min} =~ /^\d+$/) ?
                        q[&run_min=].$params->{run_min} : q[&run_min=0];

    $self->{href}   .=  (exists $params->{run_max} && $params->{run_max} && $params->{run_max} =~ /^\d+$/) ?
                        q[&run_max=].$params->{run_max} : q[&run_max=Infinity];

    $self->{href}   .=  q[&run_type=200];
    $self->{href}   .=  q[&auto_condition=186%2C187%2C188%2C189%2C190%2C191];
    $self->{href}   .=  q[&gear_type=];
    $self->{href}   .=  q[&wheel_gear=85%2C87%2Cfull];
    $self->{href}   .=  q[&steer_position=];

    $self->{href}   .=  exists $params->{nophoto} ? q[&photo_exists=] : q[&photo_exists=1];

    $self->{href}   .=  q[&seller_type=];

    if(exists $params->{date} && $params->{date} eq q[today]){
        $self->{href}   .=  q[&date_range=today];
    }
    else{
        $self->{href}   .=  q[&date_range=];
    }

    $self->{href}   .=  q[&country=24];
    $self->{href}   .=  q[&region=25];
    $self->{href}   .=  q[&city=25];
    $self->{href}   .=  q[&page=];

    $self->{converter}  =   new Text::Iconv(q[windows-1251], q[utf8]);

    bless($self);
    return $self;
}

sub getCars {
    my ($self, $page) = @_;
    $page = 1 unless $page;
    $page = 1 unless $page =~ /^\d+$/;

    my $result = Jum::Web::Crawler::getURL({href=>$self->{href}.$page});
    my $return = {};
    $return->{lastPage} =   undef;
    $return->{results}  =   [];

    if($result->{retcode} == 0 && $result->{http_code} == 200){
        Jum::Logger::ok(qq[Got $page page $self->{href}$page]);
        $result->{content} = $self->{converter}->convert($result->{content});
        $return->{lastPage} = $self->_detectLastPage(\$result->{content});
        $return->{results} = $self->_parseResults(\$result->{content});
        return $return;
    }
    else{
        Jum::Logger::error(qq[Fault on first query $self->{href}0 - retcode $result->{retcode}, http code $result->{http_code}]);
        return undef;
    }
}

sub _parseResults {
    my ($self, $content) = @_;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    my @results;
    #<a href="/market/ford/focus/offer_5846861.html?from_search=1">Ford Focus</a>
    #<a href="/market/offer.html?id=3181460&from_search=1">Volkswagen Passat 1.8 20V</a>
 #<a href="/market/ford/focus/offer_5846861.html?from_search=1"><img src="http://pic.auto.mail.ru/market/offers/2/6/265c9417e1114e5c04f44833243a0e1d_thumbnail.jpg" width="75" height="58" alt="" /></a>
    #print $$content;
    #<a href="/market/ford/focus/offer_5846861.html?from_search=1">Ford Focus</a>
    while($$content =~ /href="(\/market\/(?:[^\/]+\/){2}offer_\d+\.html)\?from_search=1">([^<]+)/isg){

        push(@results, {href=>$self->{href_prefix}.$1, model=>$2});
    }
    return \@results;
}

sub _detectLastPage {
    my ($self, $content) = @_;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    return $1 if $$content =~ /length\s*:\s*(\d+),/i;
    return undef;
}

sub getCarBrand {
    my ($self, $content) = @_;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    return $1 if $$content =~ /class="l2">([^<]+)/i;
    return undef;
}

sub getCarPrice {
    my ($self, $content) = @_;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    my $chunk = $1 if $$content =~ /<td class="price">(.*?)<\/td/is;
    return undef unless $chunk;
    my $price = $1 if $chunk =~ /((?:<i>)?\d+(?:<\/i>)?\d+)\s*руб/;
    $price =~ s/[^\d]//g;
    $price = 0 unless $price;
    return $price;
}

sub getCarModel {
    my ($self, $content) = @_;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    return $1 if $$content =~ /class="l3">([^<]+)/i;
    return undef;
}

sub getCarYear {
    my ($self, $content) = @_;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    return $1 if $$content =~ /<td>(\d{4})/;
    return undef;
}

sub getCarDistance {
    my ($self, $content) = @_;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    my $distance = $1 if $$content =~ /<th>Пробег:<\/th>\s*<td>\s*(.*?)<\/td>/is;
    return 0 unless $distance;
    $distance =~ s/[^\d]//g;
    return $distance;
}

sub getCarStatus {
    my ($self, $content) = @_;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    return Jum::Text::trim($1) if $$content =~ /<th>Состояние:<\/th>\s*<td>\s*([^<]+)\s*/is;
    return q[];
}

sub getCarOptions {
    my ($self, $content) = @_;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    my $return_hash = [];
    my $chunk = $1 if $$content =~ /class="chars">(.*?)<\/table>/is;
    return undef unless $chunk;

    while($chunk =~ /<tr>\s*<th>([^:]+):(?:<[^>]+>\s*){2}([^<]+)/isg){
        my ($name, $value) = ($1,$2);
        $value =~ s/\r//g;
        $value =~ s/\n/ /g;
        next unless $value !~ /^\s*$/;
        push(@$return_hash, {
                                name    =>  $name,
                                value   =>  $value
                            }
        );
    }
    return $return_hash;

}

sub getCarComplect {
    my ($self, $content) = @_;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    my $chunk = $1 if $$content =~ /<table class="complectation">(.*?)<\/tr>/is;
    return {} unless $chunk;
    my $return_hash = {};
    while($chunk =~ /<span>([^<]+)(?:<[^>]+>\s*){2}(.*?)<\/div>/isg){
        my $parent = $1;
        my @children = split(/<br[^>]+>/,$2);
        foreach(@children){
            next if $_ =~ /^\s*$/;
            push(@{$return_hash->{$parent}}, $_);
        }

    }
    return $return_hash;
}

sub getCarDescription {
    my ($self, $content) = @_;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    return Jum::Text::trim $1 if $$content =~ s/<div class="descr">(.*?)<\/div>//is;
    return q[];
}

sub getCarBody {
    my ($self, $content) = @_;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    return $1 if $$content =~ /img\/html\/body\/body\/\d+\.png"\s*alt="([^"]+)/is;
    return q[];

}

sub getCarImages {
    #http://pic.auto.mail.ru/market/offers/
    my ($self, $content) = @_;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    my $images_list = [];
    #"http://pic.auto.mail.ru/market/offers/d/d/dd043a59b9752c09999bf6579fa63403_medium.jpg"
    while($$content =~ /(http:\/\/pic\.auto\.mail\.ru\/market\/offers\/[^'"]+?medium\.jpg)/isg){
        my $image = $1;
        $image =~ s/medium/orig/;
        push(@$images_list, $image);
    }
    return $images_list;
}

sub getCarSeller {
    my ($self, $content) = @_;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    my $return_hash = {
        is_salon        =>  q[no],
        seller_name     =>  q[],
        seller_phones   =>  q[],
        seller_url      =>  q[],
        seller_address  =>  q[],
        seller_email    =>  q[],
        seller_city     =>  q[]
    };
    if($$content =~ /<td class="seller">/i){

        ($return_hash->{seller_name}, $return_hash->{seller_email}) = ($2, $1)
            if $$content =~ /seller">\s*(?:<a href="[^=]+=([^"]+)[^>]+>(?:<[^>]+>){3})?([^<]+)/is;
        $return_hash->{seller_phones}   =   $1  if $$content =~ /phone\slast">\s*<th>[^>]+>\s*(?:<[^>]+>\s*){2}([^<\n]+)\s*/is;
        $return_hash->{seller_city}     =   $1  if $$content =~ /stick">\|(?:<[^>]+>\s*){2}([^<]+)/;
        $return_hash->{seller_email}    =   q[] unless $return_hash->{seller_email};
        $return_hash->{seller_phones}   =   q[] unless $return_hash->{seller_phones};

        Jum::Text::trim(\$return_hash->{seller_name});

    }
    else{
        $return_hash->{seller_name} = $1 if $$content =~ /href="\/market\/autosalon_info[^"]+">([^<]+)/;
        $return_hash->{seller_phones} = $1 if $$content =~ /phone\.gif[^>]+>([^<\n]+)/is;
        $return_hash->{seller_address} = Jum::Text::trim $1 if $$content =~ /<th>Адрес:<\/th>\s*<td>([^<]+)/is;
        $return_hash->{is_salon} = q[yes];
    }

    return $return_hash;
}

1;
