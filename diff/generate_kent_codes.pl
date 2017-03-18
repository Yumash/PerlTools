use strict;
use warnings;
use Data::Dumper;
=pod
На спор в 2011 году в кабаке за 10 минут написал простой генератор последовательных кодов.
Грязно - но очевидно и работает :)
=cut

my $code_length = 10;

my @range = ('A'..'Z', 0..9);

my $range_length = ($#range+1);


# 1
my ($a,$b,$c,$d,$e,$f,$g,$h,$i,$j);

for ($a=0;$a<$range_length;$a++) {
    # 2
    for ($b=0;$b<$range_length;$b++) {
        # 3
        for ($c=0;$c<$range_length;$c++) {
            # 4
            for ($d=0;$d<$range_length;$d++) {
                # 5
                for ($e=0;$e<$range_length;$e++) {
                    # 6
                    for ($f=0;$f<$range_length;$f++) {
                        # 7
                        for ($g=0;$g<$range_length;$g++) {
                            # 8
                            for ($h=0;$h<$range_length;$h++) {
                                # 9
                                for ($i=0;$i<$range_length;$i++) {
                                    # 10
                                    for ($j=0;$j<$range_length;$j++) {
                                        printf("%s%s%s%s%s%s%s%s%s%s\n", $range[$a], $range[$b], $range[$c], $range[$d], $range[$e], $range[$f], $range[$g], $range[$h], $range[$i], $range[$j]);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


=pod
А это вариант, написанный 18.03.2017, более изящный, но всё ещё несовершенный
=cut
exit;
my %letters_hash;
my %counter_hash;

my $counter = 1;

foreach my $symbol (@range){
    $letters_hash{$counter} = $symbol.'';
    $counter_hash{$counter} = 1;
    $counter++;
}


while(1){
    START:
    for(1..$code_length){
        if($counter_hash{$_} > $range_length){
            $counter_hash{$_-1} = $counter_hash{$_-1}+1;
            $counter_hash{$_} = 1;
            goto START if $counter_hash{$_-1} > $range_length;
        }
    }
    
    my $code = q[];
    
    for(1..$code_length){
        if($counter_hash{$_} == 27){ # zero
            $code .= '0';
        }
        else{
            $code .= $letters_hash{$counter_hash{$_}};
        }
    }
    print qq[$code\n];
    last if $code eq q[9]x$code_length; # Чтобы не городить условия. Мы знаем, каким будет последний код и чтобы счётчик не пошёл заново - просто прерываем цикл.
    $counter_hash{$code_length}++;
}
exit;