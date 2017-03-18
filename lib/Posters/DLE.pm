#!/usr/bin/perl -w
package Posters::DLE;
use strict;
use warnings;
use DBI;
use Text::Iconv;
use Jum::Text;

our $VERSION = '0.01';

sub new {
    my ($self, $params) = @_;
    if(!$params){
        print qq[DB params need to continue\n];
        return undef;
    }
    if(ref($params) ne q[HASH]){
        print qq[Params must be hash ref\n];
        return undef;
    }
    if(!exists $params->{login}){
        print qq[Login to DB must be defined\n];
        return undef;
    }
    if(!exists $params->{db}){
        print qq[Login to DB must be defined\n];
        return undef;
    }    
    $self = {};
    $self->{converter} = new Text::Iconv(q[utf8], q[cp1251]);
    $self->{prefix} =   exists $params->{prefix} ? $params->{prefix} : q[dle_];
    $self->{insert_post}    =   qq[
                                    INSERT INTO $self->{prefix}post
                                    SET
                                        autor      =   'admin',
                                        date        =   NOW(),
                                        short_story =   ?,
                                        full_story  =   ?,
                                        title       =   ?,
                                        category    =   ?,
                                        alt_name    =   ?,
                                        approve     =   1,
                                        tags        =   ?
                                ];

    $self->{update_post}    =   qq[
                                    UPDATE $self->{prefix}post
                                    SET
                                        full_story = ?
                                    WHERE id = ?
                                ];

    $self->{insert_tag}     =   qq[INSERT IGNORE INTO $self->{prefix}tags SET news_id = ?, tag = ?];
    $self->{select_post_id} =   qq[SELECT id FROM $self->{prefix}post WHERE alt_name = ?];
    $self->{select_category_id} =   qq[SELECT id FROM $self->{prefix}category WHERE alt_name = ?];
    $self->{insert_category}    =   qq[INSERT INTO $self->{prefix}category SET name = ?, alt_name = ?];
    
    $self->{db_params}  =   $params;
    $self->{db_params}->{password}  = q[]   unless exists $self->{db_params}->{password};
    $self->{db_params}->{host}      = q[localhost]   unless exists $self->{db_params}->{host};
    $self->{db_params}->{port}      = 3306  unless exists $self->{db_params}->{port};
    bless($self);
    $self->{dbh} = $self->db_connect();
    if(!$self->{dbh}){
        print qq[Failed logging in to DB\n];
        exit;
    }
    
    return $self;
}

sub insertPost {
    my ($self, $params) = @_;
    return undef unless $params;
    return undef unless ref $params eq q[HASH];
    return undef unless exists $params->{title};
    return undef unless exists $params->{anons};
    return undef unless exists $params->{text};
    return undef unless exists $params->{alt_name};
    return undef unless exists $params->{tag_list};
    return undef unless exists $params->{category_list};
    return undef unless ref $params->{tag_list} eq q[ARRAY];
    return undef unless ref $params->{category_list} eq q[ARRAY];
    
    $params->{text} = $self->{converter}->convert($params->{text});
    $params->{title} = $self->{converter}->convert($params->{title});
    $params->{anons} = $self->{converter}->convert($params->{anons});
    
    my $post_id = $self->getPostID(\$params->{alt_name});
    if($post_id){
        if($self->updatePost(\$post_id, \$params->{text})){
            return $post_id;    
        }
        return undef;
    }
    
    my @category_id_list = ();
    foreach my $category (@{$params->{category_list}}){
        $category->[0] = $self->{converter}->convert($category->[0]);
        push(@category_id_list, $self->addCategory(\$category->[0], \$category->[1]));
    }
    $self->{dbh}->do(
                        $self->{insert_post}, undef,
                            $params->{anons},
                            $params->{text},
                            $params->{title},
                            join(',', @category_id_list),
                            $params->{alt_name},
                            join(',', @{$params->{tag_list}})
                    );
    if(!$self->{dbh}->errstr){
        $post_id =   $self->getPostID(\$params->{alt_name});
        return undef unless $post_id;
        foreach my $tag (@{$params->{tag_list}}){
            $tag = $self->{converter}->convert($tag);
            $self->linkTag(\$post_id, \$tag);
        }
        return $post_id;
    }
    return undef;
}

sub updatePost {
    my ($self, $post_id, $text) = @_;
    return undef unless $post_id;
    return undef unless ref $post_id eq q[SCALAR];
    return undef unless $$post_id =~ /^\d+$/;
    return undef unless $text;
    return undef unless ref $text eq q[SCALAR];
    $self->{dbh}->do($self->{update_post}, undef, $$text, $$post_id);
    print qq[$self->{dbh}->errstr\n] if $self->{dbh}->errstr;
    return $self->{dbh}->errstr ? undef : 1;
}

sub getPostID {
    my ($self, $alt_name) = @_;
    return undef unless $alt_name;
    return undef unless ref $alt_name eq q[SCALAR];
    return $self->{dbh}->selectrow_array($self->{select_post_id}, undef, $$alt_name);
}

sub addCategory {
    my ($self, $category, $alt_name) = @_;
    return undef unless $category;
    return undef unless $alt_name;
    return undef unless ref $category eq q[SCALAR];
    return undef unless ref $alt_name eq q[SCALAR];
    my $category_id = $self->getCategoryID($alt_name);
    unless($category_id){
        $self->{dbh}->do($self->{insert_category}, undef, $$category, $$alt_name);
        return $self->getCategoryID($alt_name);
    }
    return $category_id;
}

sub getCategoryID {
    my ($self, $alt_name) = @_;
    return undef unless $alt_name;
    return undef unless ref $alt_name eq q[SCALAR];
    return $self->{dbh}->selectrow_array($self->{select_category_id}, undef, $$alt_name);
}

sub linkTag {
    my ($self, $post_id, $tag) = @_;
    return undef unless $tag;
    return undef unless ref $tag eq q[SCALAR];
    return undef unless $post_id;
    return undef unless ref $post_id eq q[SCALAR];
    return undef unless $$post_id =~ /^\d+$/;
    $self->{dbh}->do($self->{insert_tag}, undef, $$post_id, $$tag);
}

sub db_connect {
    my $self = shift;
    my @connstring  =   (
                            qq[DBI:mysql:database=$self->{db_params}->{db};].
                            qq[host=$self->{db_params}->{host};port=$self->{db_params}->{port}],
                            $self->{db_params}->{login},
                            $self->{db_params}->{password},
                            {'AutoCommit' => 1, 'PrintError'=>1}
                        );
    my $dbh = eval{DBI->connect(@connstring)};
    my $i = 0;
    while (!defined($dbh)){
        last if $i>10;
        sleep(2);
        $dbh = eval{DBI->connect(@connstring)};
        $i++;
    }
    $dbh->do(qq[SET CHARSET CP1251]);
    if($dbh->errstr){
        sleep(2);
        return $self->db_connect(@connstring);
    }
    return $dbh;    
}

1;