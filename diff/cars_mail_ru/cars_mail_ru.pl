#!/usr/bin/perl -w
use strict;
use lib qw[../../lib];
use Parser::MailRu::Auto;
use Data::Dumper;
use Jum::DB;
use Jum::Logger;

=pod

Оказалось, что проще всего при отслеживании предложений и сравнению их парсить cars.mail.ru.
Личный проект, выбирал машину.

Около 2010 года. Тогда ещё не было модных модулей очередей, а тащить фреймворк для AR я не стал.

=cut

my $parser = new Parser::MailRu::Auto();

my $startPage   =   ($ARGV[0] && $ARGV[0] =~ /^\d+$/) ? $ARGV[0] : 1;

my $endPage     =   ($ARGV[1] && $ARGV[1] =~ /^\d+$/) ? $ARGV[1] : 9999;

my $dbh = Jum::DB::connect(q[auto_mail_ru]);
if(!$dbh){
    Jum::Logger::error(q[Failed connecting to DB]);
    exit;
}

our $insert_query = q[INSERT IGNORE INTO grab_queue SET queue_href = ?, queue_name = ?, queue_href_md5 = MD5(?)];

Jum::Logger::notice(qq[Getting $startPage page...]);

my $result = $parser->getCars($startPage);
if($result){
    Jum::Logger::notice(qq[Got 1 page!]);
    insertResults($result->{results});
    my $lastPage = $result->{lastPage};
    if($lastPage){
        Jum::Logger::notice(qq[Total => $lastPage pages]);
        $startPage++;
        for($startPage..$lastPage){
            my $page = $_;
            Jum::Logger::notice(qq[Getting $page / $lastPage page...]);
            $result = $parser->getCars($page);
            if($result){
                Jum::Logger::notice(qq[Got $page page!]);
                insertResults($result->{results});
                sleep(5);
            }
            else{
                Jum::Logger::error(qq[Failed getting $page page!]);
                exit;
            }
            last if $page == $endPage;
        }
    }
}
else{
    Jum::Logger::error(qq[Failed getting $startPage page!]);
}

sub insertResults {
    my $results = shift;
    if(@$results !=0 ){
        Jum::Logger::notice(q[Got ].@$results.q[ results]);
        foreach my $entry (@$results){
            Jum::Logger::ok(qq[Inserting $entry->{href}\t$entry->{model}]);
            $dbh->do($insert_query, undef, $entry->{href}, $entry->{model}, $entry->{href});
        }
    }
    else{
        Jum::Logger::error(qq[NO results!]);
    }
}
