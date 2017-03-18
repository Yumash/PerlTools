#!/usr/bin/perl -w
use strict;

package Jum::Web::Crawler;
use WWW::Curl::Easy;
use Carp qw[croak];

our @user_agents = (
    # Chrome 41
    'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2227.1 Safari/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2227.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2227.0 Safari/537.36',
    
    # Safari 7
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_3) AppleWebKit/537.75.14 (KHTML, like Gecko) Version/7.0.3 Safari/7046A194A',
    
    # Firefox 40
    'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:40.0) Gecko/20100101 Firefox/40.1',
    
    # Opera 12
    'Opera/9.80 (X11; Linux i686; Ubuntu/14.10) Presto/2.12.388 Version/12.16',
    
    # Edge 12
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.135 Safari/537.36 Edge/12.246',
    
    # IE 11
    'Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; AS; rv:11.0) like Gecko',
    'Mozilla/5.0 (compatible, MSIE 11, Windows NT 6.3; Trident/7.0; rv:11.0) like Gecko',
    
    # Palemoon (чтобы разрядить обстановку)
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:25.6) Gecko/20150723 PaleMoon/25.6.0',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:25.6) Gecko/20150723 Firefox/31.9 PaleMoon/25.6.0'
);

sub getURL {
    my $params = shift;

    croak q[HASH needed as param] if ref($params) ne 'HASH';

    croak q[HREF needed in HASH] if(!exists($params->{href}));

    $params->{href} = q[http://].$params->{href} if $params->{href} !~ /^http(s)?:\/\//;
    $params->{headers} = 0 if !$params->{headers};
    $params->{ag} = qq($user_agents[rand(($#user_agents+1))]) unless exists $params->{ag};
    $params->{timeout} = 20 if !exists $params->{timeout};
    $params->{content_length} = 600000000 if !exists $params->{content_length};
    $params->{max_redirs} = $params->{max_redirs} ? $params->{max_redirs} : 3;
    $params->{followlocation} = $params->{nofollow} ? 0 : 1;
    my $result = 'false';
    open my $oldout, ">&STDOUT" or die "Can't dup STDOUT: $!";

    close STDOUT;
    open STDOUT, "> /dev/null";
    my $retcode;

    my $curl;
    {
        $curl = new WWW::Curl::Easy;

        $curl->setopt(CURLOPT_URL, $params->{href});
        $curl->setopt(CURLOPT_INTERFACE, $params->{ip}) if exists $params->{ip};
        $curl->setopt(CURLOPT_CONNECTTIMEOUT,$params->{timeout});
        $curl->setopt(CURLOPT_TIMEOUT,$params->{timeout});
        $curl->setopt(CURLOPT_NOPROGRESS, 0);
        $curl->setopt(CURLOPT_PROGRESSFUNCTION, sub {$_[2]>$params->{content_length}?1:0});
        $curl->setopt(CURLOPT_USERAGENT,$params->{ag});
        $curl->setopt(CURLOPT_POST,1) if $params->{post};
        $curl->setopt(CURLOPT_PROXY,$params->{proxy}) if $params->{proxy};
        $curl->setopt(CURLOPT_POSTFIELDS,$params->{post}) if $params->{post};
        $curl->setopt(CURLOPT_HEADER,$params->{headers});
        $curl->setopt(CURLOPT_HTTPHEADER, $params->{headers}) if $params->{headers};
        $curl->setopt(CURLOPT_COOKIE,$params->{cookie_string}) if $params->{cookie_string};
        $curl->setopt(CURLOPT_COOKIEJAR, $params->{cookie_file}) if $params->{cookie_file};
        $curl->setopt(CURLOPT_COOKIEFILE, $params->{cookie_file}) if $params->{cookie_file};
        $curl->setopt(CURLOPT_FOLLOWLOCATION, $params->{followlocation});
        $curl->setopt(CURLOPT_MAXREDIRS, $params->{max_redirs}) if $params->{max_redirs};
        $curl->setopt(CURLOPT_REFERER,$params->{referer}) if exists $params->{referer};
        open (my $tmp_for_curl, ">", \$result);
        $curl->setopt(CURLOPT_FILE,$tmp_for_curl);
        $retcode = $curl->perform;
    }

    close STDOUT;
    open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";


    my $cp = q[];
    my $headers_length = $curl->getinfo(CURLINFO_HEADER_SIZE);
    my $length = length $result;
    if($params->{headers}){
        $length -= $headers_length;
    }

    # Определение кодировки
    #Content-Type: text/html; charset=KOI8-R
    #Content-Type" content="text/html; charset=utf-8"

    $cp = $1 if $result =~ /Content\-Type:\s*[^;]+;\s*charset\s*=\s*([^\s]+)/i;
    if($cp eq ''){
        $cp = $1 if $result =~ /;\s*charset\s*=\s*([^"'\s]+)/;
    }
    
    my $yandex_captcha = 0;
    my $yandex_ban = 0;
    my $google_captcha = 0;
    my $ycs = undef;
    
=pod
TODO: Проверка капч устарела, требует обновления при ближайшей возможности
=cut

    if($params->{href} =~ /[\.\/]yandex\./){
        $yandex_captcha = 1 if $result =~ /captcha\.yandex\.net/;
        $yandex_captcha = 1 if $curl->getinfo(CURLINFO_HTTP_CODE) == 403;
        $yandex_ban     = 1 if $result =~ /mailto:unblock\@yandex\-team\.ru\?s/;
        $ycs = $1 if $result =~ /http:\/\/captcha\.yandex\.net\/image\?key=([^"]+)"/;

    }
    if($params->{href} =~ /\[\.\/]google\./){
        $google_captcha = 1 if $result =~ /sorry\/image/;
        $google_captcha  = 1 if $curl->getinfo(CURLINFO_HTTP_CODE) == 503; # такой код при капче
    }

    my $our_headers = $curl->getinfo(CURLINFO_HEADER_OUT);
    return {
                content                 =>  $result,
                length                  =>  $length,
                retcode                 =>  $retcode,
                http_code               =>  $curl->getinfo(CURLINFO_HTTP_CODE),
                codepage                =>  $cp,
                yandex_captcha          =>  $yandex_captcha,
                yandex_ban              =>  $yandex_ban,
                google_captcha          =>  $google_captcha,
                headers_length          =>  $headers_length,
                yandex_captcha_string   =>  $ycs,
                effective_url           =>  $curl->getinfo(CURLINFO_EFFECTIVE_URL),
                our_headers             =>  $our_headers,
                content_type            =>  $curl->getinfo(CURLINFO_CONTENT_TYPE),
                ag                      =>  $params->{ag},
                ok                      =>  ($retcode == 0 && $curl->getinfo(CURLINFO_HTTP_CODE) == 200) ? 1 : 0
            };

}

1;