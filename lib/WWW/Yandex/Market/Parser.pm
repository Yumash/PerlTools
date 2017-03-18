package WWW::Yandex::Market::Parser;
use strict;
use warnings;
use utf8;
our $VERSION = '1.00';

use WWW::Curl::Easy;
use URI::Escape;
use Data::Dumper;
use POSIX qw[ceil];
use DB_File;
use Carp qw[croak];
#use constant CURLOPT_PROXYTYPE   =>   101;
#use constant CURLPROXY_SOCKS5    =>   5;

my $debug;

#sub import {
#    $debug = $_[2] if $_[1] eq q[debug];
#}

=pod

new

setUserAgents
getRandomUserAgent
setIPList
setProxyList
setIP
setUserAgent
getRandomIP
getRandomProxy
getRegionsList
searchRegion
searchResults
getModelInfo
setRegion
unsetRegion
_parseResults
_parseSingle
_getURL
_debug

=cut

sub new {
    my ($self, $params) = @_;
    $self = {};
    $self->{search_href}        =   q[http://market.yandex.ru/search.xml?text=];
    $self->{onPage}             =   10;

    $self->{ModelSuggestFile}   =   q[/tmp/www_yandex_marker_parser_model.suggest.db];
    $self->{useModelSuggest}    =   1;
    $self->{debug}              =   $debug;
    my $mod_path                =   __FILE__;
    $mod_path                   =~  s/\/[^\/]+$//;
    $self->{regions_file}       =   $mod_path.q[/regions.dat];
    $self->{regions}            =   {};
    $self->{models}             =   {};
    $self->{user_agents}        =   [];
    $self->{cookie_file}        =   undef;
    $self->{ip}                 =   undef;
    $self->{ip_list}            =   [];
    $self->{last_ip}            =   undef;
    $self->{proxy}              =   {proxy=>q[], proxy_auth=>q[], proxy_type=>q[]};
    $self->{proxy_list}         =   [];
    $self->{last_proxy}         =   undef;
    $self->{proxy_regex}        =   qr/^(https?:\/\/)?([^:]+)?:?([^@]+)?@?([\w\d:]+)$/;

    if($params){
        croak q[I need HASH as param!] unless ref($params) eq q[HASH];

        $self->{useModelSuggest}    =   $params->{useModelSuggest}  if exists $params->{useModelSuggest};
        $self->{debug}              =   $params->{debug}            if exists $params->{debug};
        $self->{ModelSuggestFile}   =   $params->{ModelSuggestFile} if exists $params->{ModelSuggestFile};
        $self->{region_code}        =   $params->{region}           if exists $params->{region};

        if(
            exists $params->{user_agents}
            && ref($params->{user_agents}) eq q[ARRAY]
            && scalar @{$params->{user_agents}} != 0
        ){
            $self->{user_agents} = $params->{user_agents};
        }

        if($params->{cookie_file}){
            croak qq[Cookie file is not writable!\n] unless -w $params->{cookie_file};
            $self->{cookie_file} = $params->{cookie_file};
        }

        if($params->{ip}){

            croak(qq[Only pure scalar or array ref is allowed for ip param\n])
                if (ref($params->{ip}) && ref($params->{ip}) ne q[ARRAY]);
            if(ref($params->{ip}) eq q[ARRAY]){
                croak qq[Empty array ref in ip param\n] if scalar (@{$params->{ip}}) == 0;
                foreach(@{$params->{ip}}){
                    next unless /^[\w\d\.]+$/;
                    push(@{$self->{ip_list}}, $_);
                }
            }
            else{
                croak(qq[Bad ip format - ].$params->{ip}.qq[\n]) unless $params->{ip} =~ /^[\w\d\.]+$/;
                $self->{ip_list} = [$params->{ip}];
            }
        }
        if($params->{http_proxy}){
            croak(qq[Only pure scalar or array ref is allowed for http_proxy param\n])
                if (ref($params->{http_proxy}) && ref($params->{http_proxy}) ne q[ARRAY]);
            if(ref($params->{http_proxy}) eq q[ARRAY]){
                croak(qq[Empty array ref in http_proxy param\n]) if scalar (@{$params->{http_proxy}}) == 0;
                foreach(@{$params->{http_proxy}}){
                    my ($proxy_auth, $proxy_href);
                    if($_ =~ /$self->{proxy_regex}/i){
                        ($proxy_auth, $proxy_href) = ($2.q[:].$3,$1.$4);
                    }
                    next unless $proxy_href;
                    push(@{$self->{proxy_list}}, {
                                                        proxy_auth  =>  $proxy_auth,
                                                        proxy       =>  $proxy_href,
                                                        proxy_type  =>  q[http]
                                                    });
                }
            }
            else{
                my ($proxy_auth, $proxy_href);
                if($params->{http_proxy} =~ /$self->{proxy_regex}/i){
                    ($proxy_auth, $proxy_href) = ($2.q[:].$3,$1.$4);
                }
                next unless $proxy_href;
                push(@{$self->{proxy_list}},{
                                                proxy_auth  =>  $proxy_auth,
                                                proxy       =>  $proxy_href,
                                                proxy_type  =>  q[http]
                                            });
            }
        }
        if($params->{socks5_proxy}){
            croak(qq[Only pure scalar or array ref is allowed for socks5_proxy param\n])
                if (ref($params->{http_proxy}) && ref($params->{socks5_proxy}) ne q[ARRAY]);
            if(ref($params->{socks5_proxy}) eq q[ARRAY]){
                croak(qq[Empty array ref in socks5_proxy param\n]) if scalar (@{$params->{socks5_proxy}}) == 0;
                foreach(@{$params->{socks5_proxy}}){
                    my ($proxy_auth, $proxy_href);
                    if($_ =~ /$self->{proxy_regex}/i){
                        ($proxy_auth, $proxy_href) = ($2.q[:].$3,$1.$4);
                    }
                    next unless $proxy_href;
                    push(@{$self->{proxy_list}}, {
                                                        proxy_auth  =>  $proxy_auth,
                                                        proxy       =>  $proxy_href,
                                                        proxy_type  =>  q[socks5]
                                                    });
                }
            }
            else{
                my ($proxy_auth, $proxy_href);
                if($params->{http_proxy} =~ /$self->{proxy_regex}/i){
                    ($proxy_auth, $proxy_href) = ($2.q[:].$3,$1.$4);
                }
                next unless $proxy_href;
                push(@{$self->{proxy_list}},{
                                                proxy_auth  =>  $proxy_auth,
                                                proxy       =>  $proxy_href,
                                                proxy_type  =>  q[socks5]
                                            });
            }
        }
    }
    if($self->{useModelSuggest}){
        tie %{$self->{models}}, "DB_File", $self->{ModelSuggestFile}, O_RDWR|O_CREAT, 0666, $DB_HASH
            or die "Cannot open file '$self->{ModelSuggestFile}' $!\n";
    }
    $self->{category_href} = q[http://market.yandex.ru/guru.xml?hid=%s&CMD=-RR=9,0,0,0-VIS=11F2-CAT_ID=%s-BPOS=%s-EXC=1-PG=10&greed_mode=false];

    $self->{item_href} = q[http://market.yandex.ru/model.xml?modelid=%s&hid=%s];
    $self->{item_prop_href} = q[http://market.yandex.ru/model-spec.xml?modelid=%s&hid=%s];
    bless($self);
    return $self;
}


sub setUserAgents {
    my ($self, $user_agents) = @_;
    return $self->_debug(q[sub setUserAgents: no user agents added!]) unless $user_agents;
    return $self->_debug(q[sub setUserAgents: not an array!]) unless ref($user_agents) eq q[ARRAY];
    return $self->_debug(q[sub setUserAgents: null array of user agents!]) unless scalar(@$user_agents) != 0;
    $self->{user_agents} = $user_agents;
    return 1;
}

sub getRandomUserAgent {
    my $self = shift;
    if(scalar @{$self->{user_agents}} != 0){
        return $self->{user_agents}->[int(rand((@{$self->{user_agents}})))];
    }
    return undef;
}

sub setIPList {
    my ($self, $ip_list) = shift;
    return $self->_debug('sub setIPList: no ip list') unless $ip_list;
    return $self->_debug('sub setIPList: ip list is not array ref') unless ref($ip_list) eq q[ARRAY];
    return $self->_debug('sub setIPList: empty ip list') unless scalar(@$ip_list) != 0;
    $self->{ip_list} = [];
    foreach(@$ip_list){
        push(@{$self->{ip_list}},$_) unless /^[\w\d\.]+$/;
    }
    return 1;
}

sub setProxyList {
    my ($self, $proxy_list, $type) = shift;
    return $self->_debug('sub setProxyList: no proxy list') unless $proxy_list;
    return $self->_debug('sub setProxyList: proxy list is not array ref') unless ref($proxy_list) eq q[ARRAY];
    return $self->_debug('sub setProxyList: empty proxy list') unless scalar(@$proxy_list) != 0;
    $type = q[http] unless $type;
    return $self->_debug('sub setProxyList: bad proxy type (only http/socks5)') if $type !~ /^(http|socks5)$/i;
    $self->{proxy_list} = [];
    foreach(@$proxy_list){
        my ($proxy_auth, $proxy_href);
        if($_ =~ /$self->{proxy_regex}/i){
            ($proxy_auth, $proxy_href) = ($2.q[:].$3,$1.$4);
        }
        next unless $proxy_href;
        push(@{$self->{proxy_list}}, {
                                        proxy_auth  =>  $proxy_auth,
                                        proxy       =>  $proxy_href,
                                        proxy_type  =>  $type
                                    });
    }
    return 1;
}

sub setIP {
    my ($self, $ip) = @_;
    return $self->_debug('sub setIP: bad IP format') unless $ip =~  /^[\w\d\.]+$/;
    $self->{ip} = $ip;
    return 1;
}

sub setUserAgent {
    my ($self, $user_agent) = @_;
    return $self->_debug('sub setUserAgent: no user agent') unless $user_agent;
    return $self->_debug('sub setUserAgent: bad var') if ref($user_agent);
    $self->{user_agents} = [$user_agent];
    return 1;
}

sub getRandomIP {
    my $self = shift;
    return $self->{ip_list}->[int(rand(@{$self->{ip_list}}))] if scalar @{$self->{ip_list}} != 0;
    return undef;
}

sub getRandomProxy {
    my $self = shift;
    return $self->{proxy_list}->[int(rand(@{$self->{proxy_list}}))] if scalar @{$self->{proxy_list}} != 0;
    return undef;
}

sub getRegionsList {
    my ($self, $return) = @_;
    my $result = {};

    if(-e $self->{regions_file} && -r $self->{regions_file}){

        open FF,"<".$self->{regions_file};
        while(<FF>){
            chop;
            if(/^([^\t]+)\t(.+)$/){

                if($return){
                    $result->{$1} = $2;
                }
                else{
                    $self->{regions}->{$1} = $2;
                }
            }

        }
        close FF;
    }
    return $return ? $result : $self->{regions};
}

sub getShopList {
    my ($self, $model_href, $page) = @_;
    $page = 1 unless $page;
    my $hid = $1 if $model_href =~ /hid=(\d+)/i;
    my $modelid = $1 if $model_href =~ /modelid=(\d+)/i;
    return $self->_debug(q[Cannot get HID or MODELID from href]) unless (!$hid || !$modelid);
    my $shop_href = q[http://market.yandex.ru/offers.xml?modelid=].$modelid.q[&hid=].$hid.q[&hyperid=].$modelid.q[&grhow=shop&nextpage=1&text=&page=].$page;

    my $result = $self->_getURL({href=>$shop_href});
    if($result->{retcode} == 0 && $result->{http_code} == 200){
        my $return = {
                        pages       =>  0,
                        total       =>  0,
                        currentPage =>  $page,
                        entries     =>  {}
        };
        #<p class="search-stat">Все цены — 59, в 59 магазинах, показаны — с 1 по 10.</p>

        if($result->{content} =~ /<p class="search-stat">[^\d]+\d+,[^\d]+(\d+)/i){
            my $total = $1;
            $return->{pages} = ceil($total/10);
            $return->{total} = $total;
        }
        while($result->{content} =~ //ismg){

        }
        return $return;
    }
    return $self->_debug('Cannot get data from yandex: '.$result->{retcode}." ".$result->{http_code});
}
sub searchRegion {
    my ($self, $pattern) = @_;
    utf8::decode($pattern);
    return $self->_debug(q[sub searchRegion: bad region name]) if $pattern !~ /^[\w\s]+$/;
    $pattern = lc $pattern;
    my $regions_found = {};
    if(scalar(keys %{$self->{regions}}) != 0){
        foreach my $region_from_hash (keys %{$self->{regions}}){
            utf8::decode $self->{regions}->{$region_from_hash};
            if(lc($self->{regions}->{$region_from_hash}) =~ /$pattern/){
                utf8::encode $self->{regions}->{$region_from_hash};
                $regions_found->{$region_from_hash} = $self->{regions}->{$region_from_hash};
            }
        }
    }
    elsif(-e $self->{regions_file} && -r $self->{regions_file}){
        open FF,"<".$self->{regions_file};
        while(<FF>){
            chop;
            if(/^([^\t]+)\t(.+)$/){
                my ($region_code, $region_name) = ($1,$2);
                utf8::decode $region_name;
                $region_name = lc($region_name);
                #print $region_name." - ".$pattern."\n";
                if($region_name =~ /$pattern/){
                    utf8::encode $region_name;
                    $regions_found->{$region_code} = $region_name;
                }
            }
        }
    }
    return $regions_found;
}

sub searchResults {
    my ($self, $query, $page) = @_;
    return $self->_debug(qq[sub searchResults: no query]) unless $query;
    $page = 0   unless $page;
    if($page && $page !~ /^\d+$/){
        return $self->_debug(qq[sub searchResults: Bad page (got $page)]);
    }

    #my $page_add = $page ? q[&page=].$page : q[];
    my $result = $self->_getURL({href=>$self->{search_href}.uri_escape($query).($page ? q[&page=].$page : q[])});
    if($result->{retcode} == 0 && $result->{http_code} == 200){
        return $self->_parseResults(\$result->{content});
    }

    return  $self->_debug(qq[sub SearchResults:
                                Bad search result - retcode $result->{retcode},
                                http-code $result->{http_code},
                                yandex-captcha string: $result->{yandex_captcha}
            ]);

}


sub getModelInfo {
    my ($self, $model_id, $hid) = @_;
    my $href = sprintf($self->{item_href},$model_id, $hid);
    print qq[Getting $href\n];
    my $result = $self->_getURL({href=>$href});

    if($result->{retcode} == 0 && $result->{http_code} == 200){

        my $model_brand = $1 if $result->{content} =~ /b-breadcrumbs__link"[^>]+>([^<]+)<\/a><\/div>/i;
        my $name = $1 if $result->{content} =~ /<h1[^>]*>([^<]+)/;
        my $images = [];

        while($result->{content} =~ /<a id="[^"]+"\s*href="([^"]+)[^>]+>\s*<img src="http:\/\/mdata[^"]/ismg){
            push(@$images, $1);
        }
        if(@$images == 0){
            while($result->{content} =~ /<img src="(http:\/\/mdata[^"]+)/ismg){
                push(@$images, $1);
            }
        }

        return {brand => $model_brand, images=>$images, name=>$name};
    }

    return  $self->_debug(qq[sub SearchResults:
                                Bad search result - retcode $result->{retcode},
                                http-code $result->{http_code},
                                yandex-captcha string: $result->{yandex_captcha}
            ]);
}

sub getModelProp {
    my ($self, $model_id, $hid) = @_;
    my $href = sprintf($self->{item_prop_href},$model_id, $hid);
    print qq[Getting $href\n];
    my $result = $self->_getURL({href=>$href});

    if($result->{retcode} == 0 && $result->{http_code} == 200){

        my $props = {};
   #<table class="b-properties"><tbody><tr><th colspan="2" class="b-properties__title">Общие характеристики</th></tr><tr><th class="b-properties__label b-properties__label-title"><span>Устройство</span></th><td class="b-properties__value">принтер/сканер/копир</td></tr><tr><th class="b-properties__label b-properties__label-title"><span>Тип печати</span></th><td class="b-properties__value">черно-белая</td></tr><tr><th class="b-properties__label b-properties__label-title"><span>Технология печати</span></th><td class="b-properties__value">лазерная</td></tr><tr><th class="b-properties__label b-properties__label-title"><span>Размещение</span></th><td class="b-properties__value">настольный</td></tr><tr><th class="b-properties__label b-properties__label-title"><span>Область применения</span></th><td class="b-properties__value">персональный</td></tr><tr><th class="b-properties__label b-properties__label-title"><span>Количество страниц в месяц</span></th><td class="b-properties__value">5000</td></tr><tr><th colspan="2" class="b-properties__title">Принтер</th></tr><tr><th class="b-properties__label b-properties__label-title"><span>Максимальный формат</span></th><td class="b-properties__value">A4</td></tr><tr><th class="b-properties__label b-properties__label-title"><span>Максимальное разрешение для ч/б печати</span></th><td class="b-properties__value">1200x1200 dpi</td></tr><tr><th class="b-properties__label b-properties__label-title"><span>Скорость печати</span></th><td class="b-properties__value">16 стр/мин (ч/б А4)</td></tr><tr><th class="b-properties__label b-properties__label-title"><span>Время выхода первого отпечатка</span></th><td class="b-properties__value">10 c (ч/б)</td></tr><tr><th colspan="2" class="b-properties__title">Сканер</th></tr><tr><th class="b-properties__label b-properties__label-title"><span>Тип сканера</span></th><td class="b-properties__value">планшетный</td></tr><tr><th class="b-properties__label b-properties__label-title"><span>Максимальный формат оригинала</span></t

   #<th colspan="2" class="b-properties__title">Общие характеристики</th></tr><tr><th class="b-properties__label b-properties__label-title"><span>Устройство</span></th><td class="b-properties__value">принтер/сканер/копир</td></tr><tr><th class="b-properties__label b-properties__label-title"><span>Тип печати</span></th><td class="b-properties__value">черно-белая</td></tr><tr><th class="b-properties__label b-properties__label-title"><span>Технология печати</span></th><td class="b-properties__value">лазерная</td></tr><tr><th class="b-properties__label b-properties__label-title"><span>Размещение</span></th><td class="b-properties__value">настольный</td></tr><tr><th class="b-properties__label b-properties__label-title"><span>Область применения</span></th><td class="b-properties__value">персональный</td></tr><tr><th class="b-properties__label b-properties__label-title"><span>Количество страниц в месяц</span></th><td class="b-properties__value">5000</td></tr><tr>

        while($result->{content} =~ /class="b\-properties__title">([^<]+)(.+?)<th colspan/ismg){
            my $parent = $1;
            my $child = $2;
            #print $child."\n";
            #_label-title"><span>Устройство</span></th><td class="b-properties__value">принтер/сканер/копир
            while($child =~ /label\-title"><span>([^<]+)(?:<[^>]+>\s*){2}<td class="b\-properties__value">([^<]+)/ismg){
                my ($name, $value) = ($1,$2);
                if(!exists $props->{$parent}){
                    $props->{$parent} = {};
                }
                $props->{$parent}->{$name} = $value;
            }
        }
        return $props;
    }

    return  $self->_debug(qq[sub SearchResults:
                                Bad search result - retcode $result->{retcode},
                                http-code $result->{http_code},
                                yandex-captcha string: $result->{yandex_captcha}
            ]);
}

sub setRegion {
    my ($self, $region_code) = @_;
    return $self->_debug(q[sub setRegion: wrong region code]) if $region_code !~ /^\d+$/;
    $self->{region_code} = $region_code;
}

sub unsetRegion {
    my $self = shift;
    $self->{region_code} = undef;
}

sub getResultsFromCategory {
    my ($self, $parent_id, $child_id, $page) = @_;
    $page = $page ? $page*10 : 0;
    my $href = sprintf($self->{category_href}, $child_id, $parent_id, $page);
    print $href."\n";
    my $result = $self->_getURL({href=>$href});
    if($result->{retcode} == 0 && $result->{http_code} == 200){
        my $total = $1 if $result->{content} =~ /<span id="m_count1">(\d+)/;
        my @results = ();
        while($result->{content} =~ /b\-offers[^"]+"\s*src="([^"]+)[^>]+>(?:<[^>]+>\s*){4}[^<]+(?:<[^>]+>\s*){5}<a.+?href="([^"]+)">([^<]+).+?offers__spec">\s*([^<]+)/ismg){
            my ($name, $href, $pic, $descr) = ($3, $2, $1, $4);
            $name =~ s/&amp;/&/g;
            $href =~ s/&amp;/&/g;
            $pic  =~ s/&amp;/&/g;
            $descr =~ s/&amp;/&/g;
            push(@results, {
                            model_name  =>  $name,
                            model_href  =>  $href,
                            model_pic   =>  $pic,
                            model_description => $descr,
                            yandex_inner       => ($href =~ /\/redir\//i) ? 0 : 1
                        });
        }
        return {total => $total, pages => ceil($total/10), results=>\@results};
    }

    return  $self->_debug(qq[sub SearchResults:
                                Bad search result - retcode $result->{retcode},
                                http-code $result->{http_code},
                                yandex-captcha string: $result->{yandex_captcha}
            ]);

}

sub _parseResults {
    my ($self, $content) = @_;
    my $results = [];
    my $total = 0;
    $$content =~ s/<b class="complain g-none">.*?<\/b>//gims;
    $$content =~ s/<\/?b[^>]*>//g;
    $$content =~ s/<p class="b-offers__spec">\s*<\/p>//g;
    $total = $1 if $$content =~ /<p class="search-stat">\D+(\d+)\./;


    while($$content =~ /b-offers__img"\s*src="([^"]+)"[^>]*>\s*.*?(<a.*?)\s*<\/div>\s*<h3[^>]+>\s*<a[^>]*?href="([^"]+)"[^>]*>(.*?)\s*<\/a>.*?<\/h3>\s*<div[^>]+>(.*?)<\/div>\s*(<p[^>]+>([^<]+))?/ismg){
        my $model_image = $1;
        my $breadcrump = $2;
        my $model_href = $3;
        my $model_title = $4;
        my $model_price = $5;

        my $model_description = $7 || q[];

        $model_title =~ s/<[^>]+>//g;

        my ($price_from, $price_to) = ($1, $2)
            if $model_price =~ /_num">((\d|\s)+)<[^>]+>[^<]*<span[^>]+>([\d\s]+)<[^>]+>/;

        if($price_from && $price_to){
            $price_from =~ s/<[^>]+>//g;
            $price_to =~ s/<[^>]+>//g;
            $price_from =~ s/\D//g;
            $price_to =~ s/\D//g;
            $model_price = ($price_from+$price_to)/2;
        }
        $model_price =~ s/<\/span>.+$//;
        $model_price =~ s/\D//g;
        my $yandex_inner = ($model_href =~ /\/redir\//i) ? 0 : 1;
        my $categories;

        while($breadcrump =~ /<a href="([^"]+)">([^<]+)/ismg){
            push(@$categories,  {
                                    category_href   =>  $1,
                                    category_name   =>  $2
                                });
        }
        my $suggested_vendor = q[];
        if($self->{useModelSuggest}){
            my @title_words = split(' ', $model_title);
            foreach my $word (@title_words){
                foreach my $vendor_from_hash (keys %{$self->{models}}){
                    if(lc($word) eq lc($vendor_from_hash)){
                        $suggested_vendor = $word;
                        last;
                    }
                    if($vendor_from_hash =~ /\b\Q$word\E\b/i){
                        $suggested_vendor = $vendor_from_hash;
                        last;
                    }
                }
            }
        }
        $model_href =~ s/&amp;/&/g;
        push(@$results, {
                            model_image         =>  $model_image,
                            model_href          =>  $model_href,
                            model_title         =>  $model_title,
                            model_price         =>  $model_price,
                            model_description   =>  $model_description,
                            model_categories    =>  $categories,
                            yandex_inner        =>  $yandex_inner,
                            suggested_vendor    =>  $suggested_vendor
                        });
    }
    return  {
                pages   =>  ceil($total/$self->{onPage}),
                results =>  $results,
                total   =>  $total
            };

}

sub _parseSingle {
    my ($self, $content) = @_;
    my $title = $1 if $$content =~ /<title>([^\–]+)/i;

    $title =~ s/\s$//;
    open FF,">./model.txt";
    print FF $$content;
    close FF;

    my $vendor  =   $1  if $$content =~ /"([^"]+)","model"/i;
    my $text    =   $1  if $$content =~ /id="full-spec-cont">(.*?)<\/div>/ism;
    my $price   =   $1  if $$content =~ /b-prices__num">([^<]+)/;

    if($self->{useModelSuggest}){
        $self->{models}->{$vendor} = 1 if !exists $self->{models}->{$vendor};
    }

    $price      =   $price ? $price : 0;
    $price      =~  s/[^\d]//g;
    my $pics_block = $1 if $$content =~ /<table class="modelpict[^>]+>(.*?)<\/table>/im;
    my $pictures;
    if($pics_block){
        while($$content =~/(http:\/\/mdata\.yandex\.net[^"]+)/gi){
            my $pic = $1;
            next if $pic =~ /(size=|blogs)/;
            push(@$pictures, $pic);
        }
    }
    my $model_info = {};
    while($text =~ /span="2" class="title">(?:<b>)?([^<]+)(?:<\/b>)?.*?<\/tr><tr>(.*?)(?:<td col|\/table>)/ismg){
        my ($group_name, $group_content) = ($1, $2);
        $model_info->{$group_name} = {};
        while($group_content =~ /<td\s*class="label"><span>(?:<b>)?([^<]+)(?:<\/b>)?<\/span><\/td><td>([^<]+)/ismg){
            $model_info->{$group_name}->{$1} = $2;
        }
    }
    return  {
                title   =>  $title,
                content =>  $model_info,
                price   =>  $price,
                images  =>  $pictures,
                vendor  =>  $vendor
            };
}

=pod

=head2 _getURL(\%params)
Получает контент страницы используя CURL.

=head3 Параметры

=over

=item href
Ссылка. Если не начинается с http:// - подставляет http автоматически

=item nofollow
Ходить ли по редиректам

=item ag
User-Agent. По умолчанию - Mozilla Firefox.

=item timeout
Таймаут запроса. По умолчанию - 20

=item nofollow
Идти ли по редиректам. По умолчанию - идти (1);

=item cookie_file
Где хранить Cookie и откуда их читать

=item referer
HTTP-реферер

=back

=head3 Возвращаемые значения

=over

=item result
HTML-код страницы

=item http_code
HTTP-код страницы

=item retcode
Код возврата CURL

=item yandex_captcha
или undef, или же хеш-код капчи

=item effective_url
Какой URL был на самом деле запрошен в цепочке редиректов, если таковая была.

=back

=cut

sub _getURL {
    my ($self, $params) = @_;
    $self->{debug} = 1;
    return $self->_debug('sub _getURL: ref of params is not a hash')    if ref($params) ne 'HASH';
    return $self->_debug('sub _getURL: You must specify a href')        if !exists $params->{href};

    $params->{href} =   q[http://].$params->{href} if $params->{href} !~ /^https?:\/\//;

    unless (exists $self->{ag}){
        if(scalar @{$self->{user_agents}} == 0){
            $self->{ag} = q[Mozilla/5.0 (Windows; U; Windows NT 5.1; ru; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3];
        }
        else{
            $self->{ag} = $self->getRandomUserAgent();;
        }
    }

    if(!$self->{ip} && scalar @{$self->{ip_list}} != 0){
        $self->{ip} =   $self->getRandomIP();
    }
    if(!$self->{proxy} && scalar @{$self->{proxy_list}} != 0){
        $self->{proxy} =   $self->getRandomProxy();
    }

    if($self->{cookie_file} && !-w $self->{cookie_file}){
        return $self->_debug('sub _getURL: '.$self->{cookie_file}.q[ is not writable]);
    }

    my $result = 'false';
    my $retcode;

    open my $oldout, ">&STDOUT" or die "Can't dup STDOUT: $!";

    close STDOUT;
    open STDOUT, "> /dev/null";
    my $cookie_string = undef;
    if(exists $self->{region_code} && $self->{region_code} && $self->{region_code} =~ /^\d+$/){
        $cookie_string = q[yandex_gid=].$self->{region_code};
    }
    my $curl;
    {
        $curl = new WWW::Curl::Easy;

        $curl->setopt(CURLOPT_URL, $params->{href});
        $curl->setopt(CURLOPT_COOKIE, $cookie_string)                       if $cookie_string;
        $curl->setopt(CURLOPT_INTERFACE, $self->{ip})                       if $self->{ip};
        $curl->setopt(CURLOPT_COOKIEFILE, $params->{cookie_file})           if $self->{cookie_file};
        $curl->setopt(CURLOPT_COOKIEJAR, $params->{cookie_file})            if $self->{cookie_file};
        $curl->setopt(CURLOPT_REFERER, $params->{referer})                  if exists $params->{referer};
        $curl->setopt(CURLOPT_USERAGENT, $self->{ag})                       if $self->{ag};
        $curl->setopt(CURLOPT_PROXYUSERPWD, $self->{proxy}->{proxy_auth})   if $self->{proxy}->{proxy_auth};
        #$curl->setopt(CURLOPT_PROXY, $self->{proxy}->{proxy})               if $self->{proxy}->{proxy};
        #if($self->{proxy}->{proxy_type} && $self->{proxy}->{proxy_type} eq 'socks5'){
        #    $curl->setopt(CURLOPT_PROXYTYPE, CURLPROXY_SOCKS5);
        #}

        $curl->setopt(CURLOPT_CONNECTTIMEOUT, 20);
        $curl->setopt(CURLOPT_TIMEOUT, 20);
        $curl->setopt(CURLOPT_NOPROGRESS, 0);
        $curl->setopt(CURLOPT_PROGRESSFUNCTION, sub {$_[2]>600000?1:0});
        $curl->setopt(CURLOPT_FOLLOWLOCATION, 1);
        $curl->setopt(CURLOPT_MAXREDIRS, 3);

        open (my $tmp_for_curl, ">", \$result);
        $curl->setopt(CURLOPT_FILE,$tmp_for_curl);
        $retcode = $curl->perform;
    }
    close STDOUT;
    open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";

    my $yandex_captcha = q[];
    $yandex_captcha   =   $1  if  $result =~  /http:\/\/captcha\.yandex\.net\/image\?key=([^"]+)"/;

    $result             =   q[] if  !$result;
    $self->{ag}         =   q[];
    $self->{last_ip}    =   $self->{ip};
    $self->{proxy}      =   undef;
    $self->{last_proxy} =   $self->{proxy};
    $self->{proxy}      =   undef;

    return  {
                content                 =>  $result,
                retcode                 =>  $retcode,
                http_code               =>  $curl->getinfo(CURLINFO_HTTP_CODE),
                effective_url           =>  $curl->getinfo(CURLINFO_EFFECTIVE_URL),
                yandex_captcha          =>  $yandex_captcha
            };

}

=pod

=head2 _debug()
Выводит отладочные сообщения если включен дебаг

=cut

sub _debug {
    my ($self, $message) = @_;
    print STDERR qq[!!!!\t$message\t!!!!\n];
    return undef;
}

sub DESTROY {
    my ($self) = @_;
    untie %{$self->{models}} if $self->{useModelSuggest};
}

=head1 AUTHOR

Andrey Yumashev, E<lt>andrey.jumashev@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Andrey Yumashev, http://yumalabs.ru

This library is not a free software; you can not redistribute it and/or modify.
=cut

1;
__END__