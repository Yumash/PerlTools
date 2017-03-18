#!/usr/bin/perl -w
use strict;
use lib qw[../lib];
use Jum::Web::Crawler;
#use Jum::DB;
use Text::Iconv;
use Data::Dumper;

=pod

Скрипт для просмотра динамики цены на золото. БД не сохранилась, но её структура очевидна из запроса.
Запись в БД отключена для возможности просмотра результата скрипта.
Регулярные выражения актуализированы на момент 18.03.2017

=cut

my $converter = new Text::Iconv(q[cp1251],q[utf8]);

#my $dbh = Jum::DB::connect(q[gold]);

my $href = q[http://wm.exchanger.ru/asp/default.asp];

my $result = Jum::Web::Crawler::getURL({href=>$href});

if($result->{ok}){
    $result->{content} = $converter->convert($result->{content});
    #print $result->{content};
    # <TABLE  class='bidsList bidStats' width=100% border='0' cellpadding='3' cellspacing='1'>
    while($result->{content} =~ /<table\s*class='bidsList[^']+[^>]+>\s*<tr[^>]+>\s*<td[^>]+>\s*[^\d]+(\d{2})\.(\d{2})\.(\d{4})(.+?)<\/table>/gis){
        my ($day, $month, $year, $content) = ($1,$2,$3,$4);
        my $date = qq[$year-$month-$day];
=pod
Example layout
<tr onclick='document.location = "/asp/wmlist.asp?exchtype=29"'>
<td align='center'   ><u>WMR-&gt;WMG</u></td>
<td align='right'   >1530,55</td>
<td align='right'   >0,63</td>
<td align='right'   >2429,4444</td>
<td align='right'   >0,0004</td>
</tr>
<tr onclick='document.location = "/asp/wmlist.asp?exchtype=30"'>
<td align='center'   ><u>WMG-&gt;WMR</u></td>
<td align='right'   >0,41</td>
<td align='right'   >937,59</td>
<td align='right'   >0,0004</td>
<td align='right'   >2286,8048</td>

=cut
        my $from = $1 if $content =~ /<u>WMR-&gt;WMG(?:<[^>]+>\s*){2}(?:<[^>]+>\s*[^<]+<[^>]+>\s*){2}<[^>]+>\s*(\d+(?:\,\d+)?)/ism;
        my $to = $1 if $content  =~ /<u>WMG-&gt;WMR(?:<[^>]+>\s*){2}(?:<[^>]+>\s*[^<]+<[^>]+>\s*){3}<[^>]+>\s*(\d+(?:\,\d+)?)/ism;
        print qq[$date $from $to\n];
        $from =~ s/,/./;
        $to =~ s/,/./;
        #$dbh->do(q[INSERT IGNORE INTO gold_grafik SET gold_date = ?, gold_to_rub = ?, gold_from_rub = ?], undef, $date, $to, $from);
    }
}
else{
    print Dumper $result;
}