#!/usr/bin/perl
# made by: KorG
#
# NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE
#  This file is a very old code and -probably- (certainly) needs refactoring.
# NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE

package caler_period;

=head1 NAME

B<caler_period.pm> is a module for period estimation.

=cut 

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use lib '.';
use Exporter 'import';
our @EXPORT = qw( caler_period caler_period_fast caler_period_quick );
our @EXPORT_OK = qw( _get_divisors );


our $DEBUG = 0;

use Data::Dumper;
sub _debug { print STDERR @_, "\n" if $DEBUG; }
use Memoize;
use POSIX;

# Термины:
#  T - hash таблица предполагаемых периодов
#
# Для каждого четного отсчёта:
#  - проверить все кратные периоды из Т
#  - проверить половинки имеющегося ряда
#

my %T = (); # таблица предполагаемых периодов
my %I = (); # таблица необходимости пересечений
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
   unless (defined $I{$_[2]}) {
      if ($_[1]) {
         if ($_[0] % 2) {
            $I{$_[2]} = 1;
         } else {
            $I{$_[2]} = 0;
         }
      } else {
         if ($_[0] % 2) {
            $I{$_[2]} = 0;
         } else {
            $I{$_[2]} = 1;
         }
      }
   }

   if ($I{$_[2]} == 1) {
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
}

# На входе предполагаются значения функции, отмеренные через равные интервалы
# времени.  Аппроксимацию и нормализацию лучше делать отдельным модулем.  
# Часть наработок можно взять из interpolator2001.pl
#

# $. - число полученных отсчётов, равно 0+@IN

sub _caler_period_read {
   shift; # skip 0th undef from carr_read()

   $. = 0;
   for (@_) {
      $.++;
      chomp;
      push @IN, $_;

      # Проверка имеющихся кратных периодов
      # (возможно имеет смысл для каждого периода сохранять число раз,
      # которое его проверяли)
      for (keys %T) {
         $T{$_} += compare subarray $_, $. % 2, $_;
         $cT{$_}++;
      }

      if ($. % 2) {
         # Проверка половинок ряда
         if ($. > 1) {
            $T{int $./2} += compare subarray int $./2, (int $./2)%2, int $./2;
            $cT{int $./2}++;
         }
      } else {
         $T{$./2} = compare subarray $./2, ($./2)%2, $./2;
         $cT{$./2} = 1;
      }
   }

   # TODO реально нужно???
   # На входе ожидаем четное число отсчётов функции для упрощения прототипа.
   die "count(\@IN)=$. not even! " if $. % 2;
}

=head1 FUNCTIONS

=over 1

=item B<caler_period(@arr)>
-- Tries to estimate a period for I<@arr> values using cumulative method.
=cut
sub caler_period {

   _caler_period_read(@_);

   for (keys %T) {
      $T{$_} /= $cT{$_};
   }

   _debug "%T = (";
   _debug join ", ", map {"$_ => $T{$_}"} sort {$T{$b}<=>$T{$a}} keys %T;
   _debug ");";

   # Sorted Keys
   my @sk = sort { $T{$a} <=> $T{$b} || $a <=> $b } keys %T;

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

   _debug "MK:", Dumper \@mk;
   _debug "Minimum value: ", $T{$sk[0]};
   _debug "Period: ", (sort { $a <=> $b } @mk)[0];

   my $i = 1;
   my $p;
   for(;;) {
      next if $i++ == ($p = shift @sk);
      last unless defined $p;
      _debug "True period: $p";
      last;
   }

   die "Cannot estimate period\n" unless defined $p;
   return $p - 1;
   # TODO объяснить, почему вычитается единица
}

# Нужно что-нибудь придумать с периодом, стремящимся к 1, если функция
# не периодическая в принципе: [ 1, 2, 3, 4, 5, 6, 7, 8 ]


# Возвращает список делителей числа
sub _get_divisors($);
sub _get_divisors($) {
   my $number = $_[0];

   my %rc;
   my $curr;

   for my $div (2..$number) {
      if ($number >= $div) {
         if ($number % $div == 0) {
            $rc{$div} = undef;
            $rc{$number} = undef;
            $curr = $number / $div;
            last if $curr == 1;
            $rc{$curr} = undef;
            @rc{_get_divisors($curr)} = undef;
         }
      } else { last }
   }

   return keys %rc;
}
memoize('_get_divisors', LIST_CACHE => 'MERGE');

# Рабочий массив
our @ARR;

# Should be called with filled @ARR
sub _get_idx_for_period {
   map { $#ARR - $_ * $_[0] } (0..floor(@ARR / $_[0])-1);
}

# Следующие функции нужны для определения сумм подмножеств @ARR длиной $_[0]
# 0 -- с начала массива; L -- слева от центра; R -- справа от центра;
# E -- в конце массива.
sub sum0 { if ($_[0] == 1) { return $ARR[0] } else {
      return $ARR[$_[0]-1] + sum0($_[0] - 1) } }
sub sumL { if ($_[0] == 1) { return $ARR[@ARR/2-1] } else {
      return $ARR[@ARR/2 - $_[0]] + sumL($_[0] - 1) } }
sub sumR { if ($_[0] == 1) { return $ARR[@ARR/2] } else {
      return $ARR[@ARR/2 + $_[0] - 1] + sumR($_[0] - 1) } }
sub sumE { if ($_[0] == 1) { return $ARR[$#ARR] } else {
      return $ARR[$#ARR - $_[0] + 1] + sumE($_[0] - 1) } }
memoize($_, LIST_CACHE => 'MERGE') for qw( sum0 sumL sumR sumE );

=item B<caler_period_fast(@arr)>
-- Tries to quickly estimate a period for I<@arr> values using full population.
=cut
sub caler_period_fast {
   # Принципиально новый метод поиска периода, применимый для имеющейся 
   # совокупности данных, не позволяющий вычислять период онлайн,
   # зато должен быстрее работать на имеющемся полном наборе данных.
   # 

   ##   my %potential_periods;
   ##   $potential_periods{$_} = 1 for (1..@_);

   # Функция для выбора индексов сравниваемых значений
   # arg0: длина выборки
   # arg1: длина массива
   # rc: ARRAYref, ARRAYref -- массивы с индексами
   ### sub _subindex {
   ###    my $len = $_[0];
   ###    my $center = floor($_[1] / 2);
   ###    return [$center-$len..$center-1], [$center..$center+$len-1];
   ### }

   # Пороговое значение для функции сравнения.
   # Поскольку функция сравнения находит сумму абсолютных разностей массивов,
   # величину R имеет смысл выбирать как ????
   ##my $R = 0.5;

   ##   for my $current (reverse 2..floor(@_/2)) {
   ##      next unless $potential_periods{$current};
   ##
   ##      # Такой алгоритм, наверное, был бы неплох; но нужно использовать 
   ##      # корреляцию и как-то выбрать $R.
   ##      my ($idx1, $idx2) = _subindex($current, 0+@_);
   ##      if ( compare([@_[@{$idx1}]], [@_[@{$idx2}]]) < $R ) {
   ##         $potential_periods{$_} = 0 for (_get_divisors $current);
   ##      }
   ##   }

   # Таблица сумм абсолютных отклонений
   ### my %diff;
   ### my $curr_diff;

   ### my %potential_periods;
   ### $potential_periods{$_} = 1 for (2..floor(@_/2));

   ### # Переберем все варианты
   ### for my $current (reverse 2..floor(@_/2)) {
   ###    # Может быть, тут как-то получится оптимизировать; но не понятно, как
   ###    print STDERR "[i:$current]";
   ###    next unless $potential_periods{$current};
   ###    print STDERR "[o:$current]";

   ###    my ($idx1, $idx2) = _subindex($current, 0+@_);
   ###    #$diff{$current} = compare([@_[@{$idx1}]], [@_[@{$idx2}]]);
   ###    use List::MoreUtils::XS qw( pairwise );
   ###    use List::Util qw( sum max min );
   ###    my @a1 = @_[@$idx1];
   ###    my @a2 = @_[@$idx2];
   ###    #$diff{$current} = $curr_diff = sum(pairwise {abs($a - $b)} @a1, @a2);
   ###    $diff{$current} = $curr_diff = sum(@a1) - sum(@a2);

   ###    print STDERR "[c: $curr_diff | " . (sum(@a1)/@a1) ." ]";
   ###    if ($curr_diff > $current * $R * max(@a1)) {
   ###       $potential_periods{$_} = 0 for (_get_divisors $current);
   ###    }
   ### }

   # Выберем наименьшее значение
   ### my $min = (sort { $diff{$a} <=> $diff{$b} || $a <=> $b } keys %diff)[0];

   # Теперь нужно как-то хитро проверить все делители $min

   ### $min;

   #TODO move up
   use List::Util qw( sum );
   use caler_arr;

   print STDERR "1\n";
   die "caler_period: array is too short" if @_ < 8;
   #TODO проверить, нужно или нет
   #die "caler_period: array % 4 != 0" if @_ % 4;
   shift while (@_ % 4); # normalize (is it OK?)

   my $max_p = @_ / 4;
   @ARR = @_;

   # For 1..$max_p estimate sums
   my %diff;

   goto 'SKIP2';
   print STDERR "4\n";

   # Приблизительная оценка на основе интегралов
   # (а может быть, тут лучше использовать средние)
   for my $curr (1..$max_p) {
      $diff{$curr}{sums} = [
         sum0($curr) / $curr, sumL($curr) / $curr,
         sumR($curr) / $curr, sumE($curr) / $curr
      ];
   }

   print STDERR "6\n";
   for my $key (keys %diff) {
      my @sums = @{$diff{$key}{sums}};
      $diff{$key}{mean} = sum(@sums) / 4;
      $diff{$key}{stddev} = carr_stddev(@sums);
   }

   # Расположим массив в порядке его обхода
   print STDERR "8\n";
   my @sorted = sort {
      $diff{$a}{stddev} <=> $diff{$b}{stddev} || $a <=> $b
   } keys %diff;

   SKIP2:

   print STDERR "10\n";
   my $AVG = sum(@ARR) / scalar(@ARR);
   print STDERR "11 avg=$AVG @{[1/$AVG]}\n";

   my $max_delta = 0;

   # Обойдем массив, сделаем быструю проверку периода
   #print "Curr\tDelta\tMod\tIdx\n";
   print STDERR "12\n";
   CURR: for my $curr (4..@ARR/4) {
      # $curr -- Это предполагаемый период
      if ($curr < 4) {
         $diff{$curr}{delta} = 0;
         next;
      }

      my $check = 1233;
      my @idx = _get_idx_for_period $curr;
      #printf "{%d $curr %d %d @idx}\n", 0+@ARR, floor($curr/4), 0+@idx;
      my $delta = abs(sum(@ARR[@idx]) / @idx - $AVG);

      my $n = 5;
      #3#  for (3..100) {
      #3#     $n = $_;
      #3#     last if $curr % $n == 0;
      #3#     if ($_ == 100) {
      #3#        #die "Failed to get even N";
      #3#        $diff{$curr}{delta} = 0;
      #3#        next 'CURR';
      #3#     }
      #3#  }
      #print STDERR "N = $n\n";
      my $hperiod = floor($curr / $n);
      #print STDERR "(curr $curr N $n hperiod $hperiod)\n";

      for (1..$n-1) {
         for (@idx) {
            $_ -= $hperiod;
         }
         @idx = grep {$_ >= 0} @idx;
         $delta += abs(sum(@ARR[@idx]) / @idx - $AVG);
      }

      $diff{$curr}{delta} = $delta;
      $max_delta = $delta if $delta > $max_delta;

      #print "$curr\t$delta\t".($curr%$ENV{PER})."\t@idx\n";
   }

   # Normalize deltas
   $diff{$_}{delta} /= $max_delta for keys %diff;

   print STDERR "14 max_delta: $max_delta\n";
   my $prev = 0;
   for ( sort { $a <=> $b } grep { $diff{$_}{delta} >= 0.5 } keys %diff) {
      printf "%d\t%d\t%d\tdelta=%.3f\n", $_, $_ - $prev, ($_ % $ENV{PER}), $diff{$_}{delta};
      $prev = $_;
   }
   #sort { $diff{$b}{delta} <=> $diff{$a}{delta} } keys %diff;

   #2#   my @y = grep{$diff{$_}{line}<=$diff{$x[$#x]}{line} / 100} @x;
   #2#   print ((scalar grep{$diff{$_}{line}<=$diff{$x[$#x]}{line} / 100} @x), " $#x -- 1% of x\n");
   #2#   print ((scalar grep{$_%$ENV{PER}==0} @x[0..@x*0.1]), " ", scalar(@x*0.1), " -- 0.1*x\n");
   #2#   print ((scalar grep{$_%$ENV{PER}==0} @y), " ", scalar(@y), " -- y\n");
   #2#   print "==(Total elements: " . scalar @ARR . "=\n";
   #2#   print "$_\t".($_%$ENV{PER})."\tmean= $diff{$_}{mean}\tline= $diff{$_}{line}\n" for
   #2#   @x[0..@x*0.1];
   #2#   print "===\n";
   #2#   print "$_\tmean= $diff{$_}{mean}\tline= $diff{$_}{line}\n" for
   #2#   @x[@x-1-@x*0.1..$#x];
   #2#   print "===\n";


   #1#   #TODO убрать дебажный вывод
   #1#   ## print "$_\tmean= $diff{$_}{mean}\tstddev= $diff{$_}{stddev}\n" for
   #1#   ## @x[0..@x*0.1];
   #1#
   #1#   my $threshold = $diff{$x[0]}{stddev} + (
   #1#      $diff{$x[$#x]}{stddev} - $diff{$x[0]}{stddev}
   #1#   ) / 10;
   #1#
   #1#   #TODO Если выгорит, подумать над 10**-4
   #1#   #NOTE: in keys for_pre_keys also was: @x[0..@x*0.1],
   #1#   my %for_pre_keys; @for_pre_keys{ 
   #1#   grep{$diff{$_}{stddev} < $threshold } keys %diff}=();
   #1#   my @for_pre_keys = keys %for_pre_keys;
   #1#
   #1#   # В куске кода ниже выбирается "период" с минимальным ско и находятся все,
   #1#   # расположенные рядом с ним, ключи и сохраняется это всё для дальнейшего
   #1#   # анализа в массиве @pre_keys
   #1#   my $min_key = $x[0];
   #1#   my @pre_keys = ($min_key);
   #1#   my $prev_key = $min_key;
   #1#   push @pre_keys, $_ for grep {
   #1#      $_ > $min_key && $_ == $prev_key + 1 && ($prev_key = $_, 1)
   #1#   } sort {$a<=>$b} @for_pre_keys;
   #1#   $prev_key = $min_key;
   #1#   push @pre_keys, $_ for grep {
   #1#      $_< $min_key && $_ == $prev_key - 1 && ($prev_key = $_, 1)
   #1#   } sort {$b<=>$a} @for_pre_keys;
   #1#   undef $prev_key; # не нужная переменная
   #1#
   #1#   my %to_check; @to_check{map _get_divisors $_, @pre_keys} = ();
   #1#   print "[$_] " for sort {$a<=>$b} keys %to_check;
   #1#
   #1#   #
   #1#   # $ time ( ../src/wavegen.pl sin -p12.3 -a5 -s150000 |awk '{print $2}' |
   #1#   # cat -n |perl -alne '$F[1]+=rand($ENV{RR});print "@F"' |
   #1#   # time perl -Mcaler_period -Mstrict -Mcaler_arr -e '
   #1#   # my@a=carr_interpolate carr_inverse(carr_read()); shift @a;
   #1#   # print caler_period_fast @a')
   #1#   # real    1m56,115s
   #1#   # user    2m8,704s
   #1#   # sys     0m1,013s
   #1#   #

   1;

   #TODO сделать вывод о том, какие $curr подходят для дальнейшего анализа
   #TODO от меньшего к большему выполнить детальный анализ
}

sub caler_period_quick {
   die "caler_period: array is too short" if @_ < 8;
   my $size = floor sqrt @_;
   shift while (@_ % $size); # normalize (is it OK?)
   @ARR = @_;

   my @diff; #resuting array
   my %diff; #resuting hash

   for my $hperiod (1..$size) {
      my @sums;
      my $sum;

      for (my $i = 0; $i < $hperiod ** 2; $i++) {
         $sums[$i % $hperiod] += $ARR[$#ARR - $i];
         $sum += $ARR[$#ARR - $i];
      }

      my $avg = $sum / ($hperiod ** 2);
      $sums[$_] /= $hperiod for (0..$#sums);

      use List::Util qw( sum max min );
      #push @{$diff[ sum map {abs($sums[$_] - $avg)} (0..$#sums) ]}, $hperiod;
      $diff{$hperiod} = sum map {abs($sums[$_] - $avg)} (0..$#sums);

      #print "$hperiod: ". sum map {abs($sums[$_] - $avg)} (0..$#sums);
   }

   my @sorted = sort { $diff{$a} <=> $diff{$b} } keys %diff;
   my $hmax = $sorted[$#sorted];
   my @divisors = _get_divisors $hmax;
   my %available;
   $available{$_} = $diff{$hmax} / ($hmax / $_) for @divisors;

   my @periods = grep { $diff{$_} >= $available{$_} } @divisors;
   print "Period: $_ avail: $available{$_} value: $diff{$_} " for @divisors;


   #my $top = pop @diff;
   #print Dumper \@diff;
}

=back
=cut

1;
