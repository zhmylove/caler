#!/usr/bin/perl
# made by: KorG

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use lib '.';

use Data::Dumper;

$\="\n";

# Термины:
#  T - hash таблица предполагаемых периодов
#
# Для каждого четного отсчёта:
#  - проверить все кратные периоды из Т
#  - проверить половинки имеющегося ряда
#

my %T = (); # таблица предполагаемых периодов
my %cT = (); # число раз, которые период был проверен
my @IN = (); # массив полученных отсчётов

# Функция, для проверки "похожести" двух массивов.  Корреляция не очень
# подходит, ввиду того, что она не учитывает абсолютные значения рядов.
# Пример: [ 1 1 1 1 1.01 ] & [ 3 3 3 3 3.01 ] будут иметь корреляцию 1.
# Поэтому функцию схожести напишем как сумму абсолютных расстояний между 
# i-ми отсчётами. 
# Важно! Если концептуально алгоритм покажет эффективность, то надо 
# переписать на обращение к одному массиву по индексам, чтобы не перемещать
# много данных каждый раз.
# a0: ARRAY ref
# a1: ARRAY ref
# rc: SCALAR
sub compare {
   die unless ref $_[0] eq "ARRAY" and ref $_[1] eq "ARRAY";
   die 0+@{$_[0]} . '!=' . 0+@{$_[1]} if 0+@{$_[0]} != 0+@{$_[1]};

   my $rc = 0;

   if (0+@{$_[0]} == 22) {
     print ' ';
     print for @{$_[0]};
     print ' ';
     print for @{$_[1]};
   }

   for my $i (0..@{$_[0]}-1) {
      $rc += abs( $_[0]->[$i] - $_[1]->[$i] );
   }

   # Нужно как-то нормировать! (возможно)
   $rc;
}

# Вспомогательная функция, которая возвращает две ссылки на массивы нужной
# длины из массива IN.
# a0: SCALAR size
# rc: ( [], [] )
sub subarray {
  if ($_[1]) {
    if ($_[0] % 2) {
      return (
        [ @IN[@IN-2*$_[0]+1 .. @IN-$_[0]] ],
        [ @IN[@IN-$_[0] .. @IN-1] ]
      ); # I
    } else {
      return (
        [ @IN[@IN-2*$_[0] .. @IN-$_[0]-1] ],
        [ @IN[@IN-$_[0] .. @IN-1] ]
      ); # 0
    }
  } else {
    if ($_[0] % 2) {
      return (
        [ @IN[@IN-2*$_[0] .. @IN-$_[0]-1] ],
        [ @IN[@IN-$_[0] .. @IN-1] ]
      ); # 0
    } else {
      return (
        [ @IN[@IN-2*$_[0]+1 .. @IN-$_[0]] ],
        [ @IN[@IN-$_[0] .. @IN-1] ]
      ); # I
    }
  }
}

# На входе предполагаются значения функции, отмеренные через равные интервалы
# времени.  Аппроксимацию и нормализацию лучше делать отдельным модулем.  
# Часть наработок можно взять из interpolator2001.pl
#

# $. - число полученных отсчётов, равно 0+@IN

while (defined($_ = <STDIN>)) {
   chomp;

   push @IN, $_;

   if ($. % 2) {
      # Проверка имеющихся кратных периодов
      # (возможно имеет смысл для каждого периода сохранять число раз, 
      # которое его проверяли)
      for (keys %T) {
         $T{$_} += compare subarray $_, $.%2;
         $cT{$_}++;
      }

      # Проверка половинок ряда
      #if ($. > 1) {
      #  $T{int $./2} += compare subarray int $./2, (int $./2)%2;
      #  $cT{int $./2}++;
      #}
   } else {
      for (keys %T) {
         $T{$_} += compare subarray $_, $.%2;
          $cT{$_}++;
       }

      $T{$./2} = compare subarray $./2, $.%2;
      $cT{$./2} = 1;
   }
}

# На входе ожидаем четное число отсчётов функции для упрощения прототипа.
die "count(\@IN)=$. not even! " if $. % 2;

#for (keys %T) {
#   $T{$_} /= $cT{$_};
#}

print STDERR "%T = (";
print STDERR join ", ", map {"$_ => $T{$_}"} sort {$T{$b}<=>$T{$a}} keys %T;
print STDERR ");";

# Sorted Keys
my @sk = sort { $T{$a} <=> $T{$b} } keys %T;

# Keys with minimum value
# В ходе эксперимента с 
# ./wavegen.pl sin -p3 | cut -d' ' -f2 | tail -318 | ./period61.pl 2>&1
# замечена такая особенность:
#  '150' => '3.24205532022904e-13',
#  '120' => '2.27184720009391e-13',
#  '90' => '3.15826286884287e-13',
#  '30' => '4.22779730721379e-13',
#  '60' => '4.325564962822e-13',
# Очевидно, выбирать нужно не наименьшее значение, а каким-то образом
# выбирать ключи, соответствующие меньшему значению с некоторым разбросом.
# Возможно, имеет смысл окгулить до int:
#
# Важно! Вероятно, такой трюк не сработает, если отклонения у функции очень
# незначительные.  Нужно придумать адекватный способ решения подобной
# проблемы.  Как вариант: выбирать не наименьшее значение, а значение, 
# входящее в наименьшие 5% выборки.  Например: 
#  [ 1, 2, 3, 4, 5, 6 ] => [ 1 ] (поскольку 1 < ( (6-1)*0.05+1 )
#  [ 1, 1.2, 3, 4, 5, 6 ] => [ 1, 1.2 ] (поскольку они < ( (6-1)*0.05+1 )
# Есть небольшой шанс, что проблема уйдет после нормализации (см. выше)
my @mk = grep { int $T{$_} == int $T{$sk[0]} } keys %T;

print STDERR "MK:", Dumper \@mk;
print "Minimum value: ", $T{$sk[0]};
print "Period: ", (sort { $a <=> $b } @mk)[0];

my $i = 1;
my $p;
for(;;) {
   next if $i++ == ($p = shift @sk);
   last unless defined $p;
   print "True period: $p";
   last;
}


# Нужно что-нибудь придумать с периодом, стремящимся к 1, если функция
# не периодическая в принципе: [ 1, 2, 3, 4, 5, 6, 7, 8 ]