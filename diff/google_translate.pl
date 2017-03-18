use strict;
use warnings;
use lib qw[../lib];
use WWW::Google::Translate;
use Data::Dumper;

my $text    =   q[Продолжаю пополнять электронный архив детских журналов.
В связи с этим разыскиваются журналы "Мурзилка" и "Веселые картинки".
Чем старше тем лучше.
Состояние любое (даже если всего несколько листов сохранилось) лишь бы было известно от какого номера.
Если кому-то жалко расстаться насовсем - отсканирую и верну (Москва).
Также если кто может отсканить сам, присылайте - наполним архив вместе.

Полный список того что есть и чего нет можно посмотреть у меня в ЖЖ:
];

my $translator  =   new WWW::Google::Translate();
$translator->set_language_from(q[ru]);
$translator->set_language_to(q[en]);
my $result  =   $translator->translate($text);

print Dumper $result;