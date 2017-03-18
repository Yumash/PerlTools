#!/usr/bin/perl -w
package Parser::MailRu::Torg;
use strict;
use warnings;
use Digest::MD5 qw[md5_hex];
use Carp qw[croak];
use URI::Escape;
use lib qw[../../];
use Jum::Logger;
use POSIX qw/ceil/;
use Jum::Text;

use Data::Dumper;

our $VERSION = '0.01';

sub getCategoryEntries {
    my $content = shift;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    my $result = [];
    while($$content =~ /href="([^"]+)"><img height="90" width="90"\s*title="([^"]+)/isg){
    #while($$content =~ /href="([^"]+)" class="t90"><b>([^<]+)/isg){
        push(@$result, {href=>$1, name=>$2});
    }
    return $result;
}


sub getCategoryLastPage {
    my $content = shift;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    my $total_models = $1 if $$content =~ /id="models_cnt1">\s*(\d+)/i;
    #Jum::Logger::ok($total_models);
    return ceil($total_models/15) if $total_models;
    return undef;
}

sub getItemCategoryName {
    my $content = shift;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    return $1 if $$content =~ /&laquo;([^&]+)&raquo;<\/label>/i;
    return undef;
}

sub getItemParams {
    my $content = shift;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    
    my $results = {};
#<tr class=parh><td colspan="2">Основные параметры</td></tr>
#			<tr id="prm187" onclick="hl_onclick(this)" onmouseover="hl_onover(this)" onmouseout="hl_onout(this)" class="parlst">
#		<td class=fst>Стандарт связи&nbsp;<a href="" onclick="return gloss(187, 'glp')">(?)</a><div id="glp187" class="off"></div></td>
#
#		<td>
#			GSM 1800, GSM 1900, GSM 900&nbsp;		</td>

    while($$content =~ /class=parh><td colspan="2">([^<]+)(?:<[^>]+>\s*){3}(.*?)<tr><td colspan=2 class=cor>/isg){
        my $parentName = $1;
        $parentName =~ s/&nbsp;/ /gi;
        Jum::Text::trim(\$parentName);
        my $children = $2;
        while($children =~ /<td class=fst>([^&<]+)(?:&nbsp;)?<[^>]+>\s*[^<]*(?:<[^>]+>\s*){5}(?:<a[^>]+>)?([^<]+)</isg){
            my ($name, $value) = ($1, $2);
            $name =~ s/&nbsp;/ /gi;
            $value =~ s/&nbsp;/ /gi;
            next if $name =~ /^\s+$/;
            Jum::Text::trim(\$name);
            Jum::Text::trim(\$value);
            $value = q[-] unless $value;
            Jum::Logger::notice(qq['$name' '$value']);
            $results->{$parentName}->{$name} = $value;
        }
    }
    
    
    return $results;    
}

sub getItemImages {
    my $content = shift;
    return undef unless $content;
    return undef unless ref $content eq q[SCALAR];
    
    my $results = [];
#class=grey><img title="Цифровой фотоаппарат CASIO Exilim Zoom EX-Z33" src="http://img.torg.mail.ru/model/174/327259/1-1.jpg"  /></a>	
    my ($imageHref, $firstImage) = ($1, $2) if $$content =~ /class=grey><img title="[^"]+"\s*src="(http:\/\/img\.torg\.mail\.ru\/model\/\d+\/\d+\/)([^"]+)"/i;
    
    return [] unless $imageHref;
    return [] unless $firstImage;
    push(@$results, $imageHref.$firstImage);
    my $photoData = $1 if $$content =~ /var pics = new Photo\(([^\)]+)/is;
    if($photoData){
        while($photoData =~ /'([^']+)/g){
            next if $1 =~ /[\]\[,]/;
            next if $1 =~ /^http:/;
            push(@$results, $imageHref.$1);
        }
    }
    return $results;
}

1;