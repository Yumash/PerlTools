package WWW::Google::Translate;
use strict;
use warnings;
use utf8;

our $VERSION = '1.00';

use Jum::Web::Crawler;
use URI::Escape;
use Data::Dumper;
use Jum::Text;
use Jum::Logger;
#http://translate.google.com/translate_a/t?client=t&text=%D1%81%D0%BE%D1%80%D0%BE%D0%BA%20%D1%82%D1%8B%D1%81%D1%8F%D1%87%20%D0%BE%D0%B1%D0%B5%D0%B7%D1%8C%D1%8F%D0%BD%20%D0%B2%20%D0%B6%D0%BE%D0%BF%D1%83%20%D1%81%D1%83%D0%BD%D1%83%D0%BB%D0%B8%20%D0%B1%D0%B0%D0%BD%D0%B0%D0%BD&hl=en&sl=ru&tl=en&multires=1&trs=1&prev=btn&ssel=5&tsel=5&sc=1



sub new {
    my $self = shift;

    $self = {};
    $self->{language_from}  =   q[en];
    $self->{language_to}    =   q[ru];

    $self->{get_href}   =   q[http://translate.google.com/translate_a/t?client=t&text=%s&hl=en&sl=%s&tl=%s&multires=1&trs=1&prev=btn&ssel=5&tsel=5&sc=1];
    $self->{post_href}       =   q[http://translate.google.com/];

    $self->{post_data}  =   q[sl=%s&tl=%s&js=n&prev=_t&hl=en&ie=UTF-8&layout=2&eotf=1&text=%s&file=];

    $self->{get_referer}    =   q[http://translate.google.com/#%s|%s|%s];

    $self->{post_referer}   =   q[http://translate.google.com/];
    bless $self;
    return $self;
}

sub set_language_from {
    my ($self, $language) = @_;
    $self->{language_from}  =   $language;
}

sub set_language_to {
    my ($self, $language) = @_;
    $self->{language_to}    =   $language;
}

sub translate {
    my ($self, $text) = @_;
    return undef unless $text;
    $text = uri_escape($text);

    my $result  =   {};
    if(length $text < 100){
        $result = Jum::Web::Crawler::getURL({
                                                href    =>  sprintf(
                                                                    $self->{get_href},
                                                                        $text,
                                                                        $self->{language_from},
                                                                        $self->{language_to}
                                                                    ),
                                                referer =>  sprintf(
                                                                    $self->{get_referer},
                                                                        $self->{language_from},
                                                                        $self->{language_to},
                                                                        $text
                                                                    )
                                            });
    }
    else{
        $result =   Jum::Web::Crawler::getURL({
                                                href    =>  $self->{post_href},
                                                referer =>  $self->{post_referer},
                                                post    =>  sprintf(
                                                                $self->{post_data},
                                                                    $self->{language_from},
                                                                    $self->{language_to},
                                                                    $text
                                                            )
                                            });
    }

    if($result->{retcode} == 0 && $result->{http_code} == 200){
        my $translated_text = $1 if $result->{content} =~ /^\[{3}"(.+?)","/is;
        if($translated_text){
            my $word;
            while($result->{content} =~ /\[\["(.+?)",/isg){
                $word = $1;
                next if length $word < 3;
                next if $word =~ /\u/;
                $translated_text =~ s/\Q$word\E/ $word /igs;
            }
            $translated_text =~ s/\s\s*/ /g;
        }
        else{
            while($result->{content} =~ /<span title="[^>]+>([^<]+)/isg){
                $translated_text .= $1.q[ ];
            }
        }
        return Jum::Text::trim($translated_text);
    }
    else{
        Jum::Logger::error(qq[Failed getting translation for text. $result->{retcode} $result->{http_code}]);
        Jum::Logger::error(qq[Content was $result->{content}]);
        return undef;
    }
    Jum::Logger::error(qq[Unknown error - we got text but no translate?]);
    return undef;
}

1;