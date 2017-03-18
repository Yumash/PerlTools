use strict;
use warnings;
use utf8;

=head1 NAME

Jum::Mystem - нормализатор контента с использованием mystem

=head1 SYNOPSIS

    use Jum::Mystem;

    my $mystem = new Jum::Mystem({mystem_path=>/usr/bin/mystem});

    if(!$mystem){
        die(qq[Cannot initalize mystem\n]);
    }
    my $content = $mystem->getString('some russian words');


=head1 DESCRIPTION

Модуль предназначен для нормализации контента с использованием программы mystem - от Яндекса.

=head1 REQUIRED MODULES

L<IPC::Open2>


=head1 EXPORT

None.

=head1 CONSTRUCTOR

=head2 new()

Создаёт объект, привязанный по сокету к mystem.

Принимает на вход: HASH REF

=over

=item * C<< mystem_path => /path/to/bin/mystem >>

Путь к mystem, необязательный параметр. По умолчанию - ../bin/mystem - в рамках проекта.

=back


=cut

package Jum::Mystem;

use IPC::Open2;
use Text::Iconv;

local $| = 1;


sub new {
    my ($class, $params) = @_;

    my $self = {
        ### PID пайпа на mystem
        'stemmer_pid'           => undef,
        ### STDIN mystem-а
        'stemmer_stdout'        => undef,
        ### STDOUT mystem-а
        'stemmer_stdin'         => undef,
        ### Кеш лемм
        'cache'                 => {},
        ### Статистика по использованию кеша
        'stat'                  => {'short' => 0, 'cached' => 0, 'uncached' => 0}
    };
    $self->{from_utf8} = new Text::Iconv(q[UTF8], q[Windows-1251]);
    $self->{to_utf8} = new Text::Iconv(q[Windows-1251], q[UTF8]);
    $self->{no_suggest} = exists $params->{no_suggest} ? 0 : 1;
    $self->{'mystem_path'}  = '/home/common/bin/mystem';
    if(ref($params) eq q[HASH]){
        $self->{'mystem_path'}  =   $params->{mystem_path} if $params->{mystem_path};
    }
    return undef unless -e $self->{mystem_path} && -X $self->{mystem_path};
    $self->{'stemmer_pid'}  =   open2(
        $self->{'stemmer_stdout'},
        $self->{'stemmer_stdin'},
        $self->{mystem_path} . " -c -n"
    );

    bless $self, $class;

    return $self;

}

=head1 PUBLIC METHODS

=head2 $mystem->_lemmatize($string);

Возвращает нормализованную строку в формате mystem - слово{нормализованное слово}

Принимает на вход: SCALAR, простой текст.

=cut

sub _lemmatize {
    my ($self, $content) = @_;
    my $stdin = $self->{'stemmer_stdin'};
    my $stdout = $self->{'stemmer_stdout'};

    #binmode $stdin, ':utf8';
    #binmode $stdout, ':utf8';
    binmode $stdin;
    binmode $stdout;
    my @words = split(/\s+/, $content);
    my @result = ();

    foreach my $word (@words) {
        #next if $word =~ /^\s*$/;
        if (($word =~ /[\da-z]/i) || (length($word) == 1)) {
            ### цифры, английские буквы и короткие слова выводим как есть, не трогая mystem
            push(@result, $word . '{' . $word . '}');

            ### Считаем статистику по коротким словам
            $self->{'stat'}->{'short'}++;

        } else {
            ### Проверяем кеш на наличие слова
            if (exists($self->{'cache'}{$word})) {
                ### Слово есть в кеше
                push(@result, $self->{'cache'}{$word});

                ### Считаем статистику по кешированным словам
                $self->{'stat'}{'cached'}++;
            } else {
                ### Слова еще нет в кеше - отдаем в mystem
                ### Странные строки ниже связаны с особенностями работы mystem в режиме STDIO
                ### Запрос разработчикам уже отправлен, обещают исправить в следующей версии :)
                ### UPD: на момент 18.03.2017 нет обновления

                $word .= qq[ EOL\n];

                print $stdin $word;
                #print $word;

                while (my $str = <$stdout>) {
                    chomp($str);

                    last if $str eq 'EOL{EOL??}';

                    if (!$str || ($str eq '\n') || ($str eq '_')) {
                        next;
                    }
                    if($str =~ /\?/ && $self->{no_suggest}){
                        last;
                    }

                    push(@result, $str);
                    ### Сохраняем на будущее
                    $self->{'cache'}{$word} = $str;

                    ### Считаем статистику по некешированным словам
                    $self->{'stat'}{'uncached'}++;
                }
            }
        }
    }

    my $result = join(' ', @result);
    $result =~ s/\?+//g;
    $result =~ s/_//g;
    return $result;
}

=head2 $mystem->getNative($string);

Альяс для метода _lemmatize

Принимает на вход: SCALAR, простой текст.

=cut

sub getNative {
    my ($self, $content) = @_;
    return $self->_lemmatize($content);
}


=head2 getNativeCorrect($content)

Функция возвращает нормализованный текст заменяя символ ^{^} на ^

=head3 Входные параметры

=head4 $content

Строка. Обязательный. Текст для нормализации

=head3 Возвращаемые значения 

Строка

=cut

sub getNativeCorrect {
    my ($self, $content) = @_;
    
    my $text = $self->getNative($content);
    $text =~ s/\^\{\^\}/\^/g;
    return $text;
}


=head2 $mystem->getString($string);

Расширенный альяс для метода _lemmatize

Принимает на вход: SCALAR, простой текст.

Возвращает: простую нормализованную строку

=cut

sub getString {
    my ($self, $content) = @_;
    
    $content = $self->{from_utf8}->convert($content);
    $content = $self->_lemmatize($content);
    $content = $self->{to_utf8}->convert($content);
    my $result = [];
    while($content =~ /\{([^\}\|]+)/g){
        push(@$result, $1);
    }
    return join(" ", @$result);
}

=head2 $mystem->getHashRef($string);

Расширенный альяс для метода _lemmatize

Принимает на вход: SCALAR, простой текст.

Возвращает: хеш-референс с результатами - слово=>нормализованное слово

=cut

sub getHashRef {
    my ($self, $content) = @_;
    $content = $self->_lemmatize($content);
    my $result = {};
    while($content =~ /([^\s]+)\{([^\}\|]+)/g){
        $result->{$1} = $2;
    }
    return $result;
}

=head2 C<VOID> sub DESTROY

Деструктор класса.

=cut

sub DESTROY {
    my $self = shift;

    my $stdin = $self->{'stemmer_stdin'};
    my $stdout = $self->{'stemmer_stdout'};
    close $stdin;
    close $stdout;
    waitpid($self->{'stemmer_pid'}, 0);
}

1;
__END__
