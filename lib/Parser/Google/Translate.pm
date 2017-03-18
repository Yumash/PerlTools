#!/usr/bin/perl -w
package Parser::Google::Translate;
use strict;
use warnings;

use WWW::Curl::Easy;
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
    $self->{href}   =   q[http://translate.google.com/translate_a/t];
    $self->{href}   .=  q[?client=t];
    $self->{href}   .=  q[&hl=ru];
    $self->{href}   .=  q[&sl=en];
    $self->{href}   .=  q[&tl=ru];
    $self->{href}   .=  q[&multires=1];
    $self->{href}   .=  q[&oc=0];
    $self->{href}   .=  q[&prev=btn];
    $self->{href}   .=  q[&sc=1];
    $self->{href}   .=  q[&text=];
    
    $self->{ip}     =   undef;
    
    $self->{debug}  =   1;
    bless $self;
    return $self;
}


sub enableDebug {
    my ($self, $trigger) = @_;
    $self->{debug} = $trigger ? 1 : 0;
}

sub setIP {
    my ($self, $ip) = @_;
    $self->{ip} = $ip if $ip;
}

sub translate {
    my ($self, $query) = @_;
    return undef unless $query;
   # $query =~ s///;
    my $result = Jum::Web::Crawler::getURL({href=>$self->{href}.uri_escape($query), ip=>$self->{ip}});
    if($result->{retcode} == 0 && $result->{http_code} == 200){
        #Jum::Logger::ok(qq[Got normal result on $query ...checking...]) if $self->{debug};
        #[[["Студия в аренду, Южная Африка. ","Studio for Rent in , South Africa.","Studiya v arendu, Yuzhnaya Afrika. "],["^ ^\n","^^","^ ^\n"],["\u003cbr /\u003e\n","\u003cbr /\u003e","\u003cbr /\u003e\n"],["\u003cbr /\u003e\n","\u003cbr /\u003e","\u003cbr /\u003e\n"],["Телефон агента (Реф: 1517-29404)","Telephone agent (property ref: 1517-29404)","Telefon agenta (Ref: 1517-29404)"]],,"en"]
        my $translationPool = [];
        while($result->{content} =~ /\["(.+?)","/g){
            push(@$translationPool, $1);
        }
        #my $translation = $1 if $result->{content} =~ /^\[{3}".+?","/;
        my $translation = join("", @$translationPool);
        $translation =~ s/\\u003c/</g;
        $translation =~ s/\\u003e/>/g;

        return $translation if $translation;                                     
    }
    Jum::Logger::error(qq[Failed translation of $query => $result->{retcode} $result->{http_code}]) if $self->{debug};
    return undef;
}
