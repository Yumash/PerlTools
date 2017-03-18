#!/usr/bin/perl -w
package Posters::Drupal;
use strict;
use warnings;

use WWW::Curl::Easy;
use Digest::MD5 qw[md5_hex];
use Carp qw[croak];
use URI::Escape;

our $VERSION = '0.01';

sub new {
    my ($self, $params) = @_;
    if(!$params){
        print qq[No params\n];
        return undef;
    }
    if(ref($params) ne q[HASH]){
        print qq[Not hash\n];
        return undef;
    }
    if(!exists $params->{url} || !$params->{url}){
        print qq[URL need to continue\n];
        return undef;
    }
    $self = {};
    $self->{cookie_file} = $params->{cookie_file} ? $params->{cookie_file} : q[/tmp/drupal].md5_hex(rand());

    print qq[Got $self->{cookie_file}\n];

    return undef if $self->{cookie_file} !~ /^[\/a-z\d\.]+$/i;
    return undef if     $self->{cookie_file} =~ /\.\./;
    unlink $self->{cookie_file} if -e $self->{cookie_file};
    `touch $self->{cookie_file}`;
    if(!-e $self->{cookie_file}){
        print qq[No $self->{cookie_file}\n];
        return undef;
    }

    #print qq[All is OK with $self->{cookie_file}\n];
    $self->{url} = $params->{url};
    $self->{url} = q[http://].$self->{url} unless $self->{url} =~ /^https?:\/\//i;
    $self->{url} =~ s/\/*$//;

    $self->{debug}  =   $params->{debug} ? 1 : 0;

    $self->{login_postfix}  =   q[/user];
    $self->{post_postfix}   =   q[/node/add/article?render=overlay&render=overlay];
    $self->{list_postfix}   =   q[/admin/content/node];
    $self->{delete_postfix} =   q[];
    $self->{admin_postfix}  =   q[/admin];

    $self->{login}      =   $params->{login};
    $self->{password}   =   $params->{password};
    bless($self);
    if($params->{login} && $params->{password}){
        $self->debug(q[Trying to login]);
        return undef unless $self->login($params->{login}, $params->{password});
    }

    return $self;
}

sub get_cookie_file {
    my $self = shift;
    open FF, "<$self->{cookie_file}";
    my $cookie_content = <FF>;
    close FF;
    return {
        name    =>  $self->{cookie_file},
        content =>  $cookie_content
    };
}
sub login {
    my ($self, $login, $password) = @_;
    $self->debug(qq[Using $self->{url}$self->{login_postfix}]);
    my $result = $self->getURL({href=>$self->{url}.$self->{login_postfix}});
    if($result->{retcode} == 0 && $result->{http_code} == 200){
        #<input type="hidden" name="form_build_id" value="form-JWrm81n9AFu18usAbWQMra3PF8fc7w16epQvpaYSKFY" /
        my $form_string = $1 if $result->{content} =~ /name="form_build_id" (?:id="[^"]+")?\s*value="([^"]+)"/;
        if(!$form_string){
            $self->debug(q[Cannot detect form string on login]);
            return undef;
        }

        my $post_string = qq[name=$login&pass=$password&form_id=user_login&op=Log+in&form_build_in=].$form_string;
        #$self->debug($post_string);
        $result = $self->getURL({href=>$self->{url}.$self->{login_postfix}, post=>$post_string});
        #$self->debug($result->{retcode});
        #$self->debug($result->{http_code});
        #$self->debug($result->{effective_url});

        if($result->{retcode} == 0 && $result->{http_code} == 200){
            return 1 if $result->{effective_url} ne $self->{url}.$self->{login_postfix};
        }
    }
    else{
        $self->debug(qq[Got fault from login initiation - $result->{retcode} $result->{http_code}]);
    }
    return undef;
}

sub is_logged_in {
    my $self = shift;
    my $result = $self->getURL({href=>$self->{url}.$self->{admin_postfix}});
    if($result->{retcode} == 0 && $result->{http_code} == 200){
        return 1;
    }
    return undef;
}

sub add_node {
    my ($self, $post_params) = @_;

    return undef unless ref $post_params eq q[HASH];
    return undef unless exists $post_params->{title};
    return undef unless exists $post_params->{body};

    my $result = $self->getURL({href=>$self->{url}.$self->{post_postfix}});
    if($result->{retcode} == 0 && $result->{http_code} == 200){
        if($result->{content} =~ /value="(main\-menu:\d+)">\-*\s*\Q$post_params->{title}\E</i){
            $self->debug(qq[Page with title $post_params->{title} already exists]);
            $self->debug(qq[Ignore existing $post_params->{title}]) if $post_params->{ignore_exists};
            return undef if !$post_params->{ignore_exists};
        }
        my $parent_data = q[main-menu:0];
        if(exists $post_params->{parent} && $post_params->{parent}){
            #value="primary-links:118">-- Testpage
            my $menu_copy = $post_params->{parent};

            utf8::decode $menu_copy;
            if(length $menu_copy > 20){
                $menu_copy = $1 if $menu_copy =~ /^(.{20})/;
            }
            $menu_copy =~ s/\s*$//;
            utf8::encode $menu_copy;

            print qq[Trying to locate $menu_copy\n];
            #<option value="main-menu:341">-- Test</option>
            if($result->{content} =~ /value="(main\-menu:\d+)">\-*\s*\Q$menu_copy\E/i){
                $parent_data = $1;
                $self->debug(qq[Detected parent node $parent_data]);
            }
            else{

                #print $result->{content};
                $self->debug(qq[Cannot determine parent node for $post_params->{parent} [$menu_copy]]);
                exit;
                return undef;

            }
        }
        my $form_build_in = $self->_get_form_build_in(\$result->{content});
        my $form_token    = $self->_get_form_token(\$result->{content});

        if(!$form_build_in){
            $self->debug(q[No form build in!\n]);
            return undef;
        }
        if(!$form_token){
            $self->debug(q[No form token!\n]);
            return undef;
        }
#title	Test
#field_tags[und]
#body[und][0][summary]
#body[und][0][value]	wtest
#body[und][0][format]	filtered_html
#files[field_image_und_0]
#field_image[und][0][fid]	0
#field_image[und][0][displ...	1
#changed
#form_build_id	form-NyZ4CCt-L-xss7rScHpxdRn4cn9ZtL8utJbbfsauMPA
#form_token	wvyHM0nKxenH2CkRQIVrBo-uoKJ-qEpk6ELgZS6bJtc
#form_id	article_node_form
#menu[enabled]	1
#menu[link_title]	Test123
#menu[description]
#menu[parent]	main-menu:341
#menu[weight]	0
#log
#path[alias]
#comment	2
#name	admin
#date
#status	1
#promote	1
#additional_settings__acti...	edit-menu
##op	Сохранить
        my $post_string = q[];
        $post_string .= q[title=].uri_escape($post_params->{title});
        $post_string .= q[&menu%5Blink_title%5D=].uri_escape($post_params->{title});
        $post_string .= q[&menu%5Bparent%5D=].uri_escape($parent_data);
        $post_string .= q[&menu%5Bweight%5D=0];
        $post_string .= q[&menu%5Bdescription%5D=0];
        $post_string .= q[&menu%5Benabled%5D=1];
        $post_string .= q[&changed=];
        #$post_string .= q[&teaser_include=1];
        $post_string .= q[&body%5Bund%5D%5B0%5D%5Bvalue%5D=].uri_escape($post_params->{body});
        $post_string .= q[&body%5Bund%5D%5B0%5D%5Bsummary%5D=];
        $post_string .= q[&body%5Bund%5D%5B0%5D%5Bformat%5D=filtered_html];
        $post_string .= q[&format=2];
        $post_string .= q[&form_build_id=].$form_build_in;
        $post_string .= q[&form_token=].$form_token;
        $post_string .= q[&form_id=article_node_form];
        $post_string .= q[&path%5Balias%5D=];
        $post_string .= q[&log=];
        $post_string .= q[&comment=2];
        $post_string .= q[&name=admin];
        $post_string .= q[&date=];
        $post_string .= q[&status=1];
        $post_string .= q[&promote=1];
        $post_string .= q[&op=Сохранить];

        $result = $self->getURL({href=>$self->{url}.$self->{post_postfix}, post=>$post_string});
        if($result->{retcode} == 0 && $result->{http_code} == 200){
            # надо проверить - что мы там запостили ваще.
            if($result->{effective_url} ne $self->{url}.$self->{post_postfix}){
                # будем условно считать что запостили
                $self->debug(qq[Successfully posted $result->{effective_url}]);
                return 1;
            }
            print $result->{content};
            $self->debug(qq[We have an unidentified error. URL was $result->{effective_url}]);
            $self->debug($post_string);
            return undef;
        }
        else{
            $self->debug(qq[POST failed - $result->{retcode} - $result->{http_code}]);
            $self->debug($post_string);
            return undef;
        }
    }
    else{
        $self->debug(q[FAILED to get content for adding content!]);
        return undef;
    }

}

sub _get_form_build_in {
    my ($self, $content) = @_;
    return undef unless ref $content eq q[SCALAR];
    return $1 if $$content =~ /name="form_build_id"\s*(?:id="[^"]+"\s+)?value="([^"]+)"/;
    return undef;
}

sub _get_form_token {
    my ($self, $content) = @_;
    return undef unless ref $content eq q[SCALAR];
    return $1 if $$content =~ /name="form_token"\s*(?:id="[^"]+"\s+)?value="([^"]+)"/;
    return undef;
}

sub delete_node {
    my ($self, $title) = @_;
    return undef unless $title;

    my $result = $self->getURL({href=>$self->{url}.$self->{list_postfix}});
    if($result->{retcode} == 0 && $result->{http_code} == 200){
        # Ищем страницу в контенте
        my $node_id = $1 if $result->{content} =~ /href=".+?\/(\d+)">\Q$title\E</;
        if(!$node_id){
            $self->debug(qq[Cannot find node id for $title]);
            return undef;
        }
        $result = $self->getURL({href=>$self->{url}.q[/node/].$node_id.q[/delete?destination=admin%2Fcontent%2Fnode]});
        if($result->{retcode} == 0 && $result->{http_code} == 200){
            my $form_build_in = $self->_get_form_build_in(\$result->{content});
            my $form_token    = $self->_get_form_token(\$result->{content});
            return $self->delete_node_by_id($node_id, $form_build_in, $form_token);
        }
        else{
            $self->debug(qq[Cannot get delete page for $node_id]);
            return undef;
        }
    }
    else{
        $self->debug(qq[Some error on getting list pages $result->{retcode} $result->{http_code}]);
        return undef;
    }
}

sub delete_node_by_id {
    my ($self, $node_id, $form_build_id, $form_token) = @_;
    #http://evilman.ru/drupal/node/10/delete?destination=admin%2Fcontent%2Fnode
    #POST /drupal/node/10/delete?destination=admin%2Fcontent%2Fnode HTTP/1.1

    return undef unless $node_id;
    return undef unless $node_id =~ /^\d+$/;
    return undef unless $form_build_id;
    return undef unless $form_token;

    my $post_string = q[];
    $post_string .= q[confirm=1];
    $post_string .= q[&op=Delete];
    $post_string .= q[&form_build_id=].$form_build_id;
    $post_string .= q[&form_token=].$form_token;
    $post_string .= q[&form_id=node_delete_confirm];

    my $result  =   $self->getURL({
                            href    =>  $self->{url}.q[/node/].$node_id.q[/delete?destination=admin%2Fcontent%2Fnode],
                            referer =>  $self->{url}.q[/node/].$node_id.q[/delete?destination=admin%2Fcontent%2Fnode],
                            post    =>  $post_string
                    });
    if($result->{retcode} == 0 && $result->{http_code} == 200){
        return 1 if $result->{effective_url} eq $self->{url}.$self->{list_postfix};
    }
    return undef;
}
sub getURL {
    my ($self, $params) = @_;

    croak q[HASH needed as param]   unless ref $params eq 'HASH';
    croak q[HREF needed in HASH]    unless exists $params->{href};

    $params->{headers}          = 0         if !$params->{headers};
    $params->{timeout}          = 20        if !exists $params->{timeout};
    $params->{content_length}   = 600000000 if !exists $params->{content_length};

    my $result = 'false';
    open my $oldout, ">&STDOUT" or die "Can't dup STDOUT: $!";

    close STDOUT;
    open STDOUT, "> /dev/null";
    my $retcode;
    $self->debug(qq[Using $self->{cookie_file}]);
    my $curl;
    {
        $curl = new WWW::Curl::Easy;

        $curl->setopt(CURLOPT_URL, $params->{href});
        $curl->setopt(CURLOPT_CONNECTTIMEOUT,$params->{timeout});
        $curl->setopt(CURLOPT_TIMEOUT,$params->{timeout});
        $curl->setopt(CURLOPT_NOPROGRESS, 0);
        $curl->setopt(CURLOPT_PROGRESSFUNCTION, sub {$_[2]>$params->{content_length}?1:0});
        $curl->setopt(CURLOPT_USERAGENT, q[Drupal Poster v.0.1]);
        $curl->setopt(CURLOPT_HEADER,$params->{headers});
        $curl->setopt(CURLOPT_FOLLOWLOCATION,1);
        $curl->setopt(CURLOPT_INTERFACE, $self->{ip})           if exists $self->{ip};
        $curl->setopt(CURLOPT_COOKIEJAR, $self->{cookie_file})  if $self->{cookie_file};
        $curl->setopt(CURLOPT_COOKIEFILE, $self->{cookie_file}) if $self->{cookie_file};
        $curl->setopt(CURLOPT_PROXY,$self->{proxy})             if $self->{proxy};
        $curl->setopt(CURLOPT_POSTFIELDS,$params->{post})       if $params->{post};
        $curl->setopt(CURLOPT_POST,1)                           if $params->{post};
        $curl->setopt(CURLOPT_REFERER,$params->{referer})       if exists $params->{referer};
        open (my $tmp_for_curl, ">", \$result);
        $curl->setopt(CURLOPT_FILE,$tmp_for_curl);
        $retcode = $curl->perform;
    }

    close STDOUT;
    open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";
    return {
                content                 =>  $result,
                retcode                 =>  $retcode,
                http_code               =>  $curl->getinfo(CURLINFO_HTTP_CODE),
                effective_url           =>  $curl->getinfo(CURLINFO_EFFECTIVE_URL),
                content_type            =>  $curl->getinfo(CURLINFO_CONTENT_TYPE)
            };

}

sub debug {
    my ($self, $msg) = @_;
    return undef unless $self->{debug};
    print $msg."\n";
}

1;
