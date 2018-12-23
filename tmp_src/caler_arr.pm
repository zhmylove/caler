#!/usr/bin/perl
# Made by: KorG

package caler_arr;

=head1 NAME

B<caler_arr.pm> is a module for simple array operations.

=cut 

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use Exporter 'import';
our @EXPORT = qw( carr_read carr_dump carr_inverse carr_interpolate );

=head1 FUNCTIONS

=over 1

=item B<stub()>
-- just a stub function
=cut
sub stub {
   print 1;
}

=item B<carr_interpolate(@arr)>
-- really strange interpolation.

This algorithm wents backwards through I<@arr> and fills any I<undef> with
a closest defined right-hand side value.
=cut
sub carr_interpolate {
   # An array should at least contain [0] and [1]
   die "carr_interpolate: empty array\n" if @_ <= 1;

   my $rvalue;
   my @arr;
   die "carr_interpolate: ivalid rvalue in array\n" unless defined $_[$#_];
   for (my $i = $#_; $i >= 1; $i--) {
      $rvalue = $_[$i] if defined $_[$i];
      $arr[$i] = $rvalue;
   }

   return @arr; # explicit return
}

=item B<carr_inverse()>
-- assuming values are IAT, produce array of lambdas = 1/IAT
=cut
sub carr_inverse {
   map { defined $_ ? 1 / $_ : undef } @_;
}

=item B<carr_dump(@arr)>
-- print the arr elements with corresponding indicies
=cut
sub carr_dump {
   local $\ = "";
   for (my $i = 1; $i < @_; $i++) {
      print "[$i]=\"" . ($_[$i] // '') . "\" ";
   }
   print "\n";
}

=item B<carr_read()>
-- return readed from STDIN array.  

Input format: <index> <value>.  I<index> should increment every line.
=cut
sub carr_read {
   my $prev_index = 0;
   my @arr;
   my @line;
   while(defined($_ = <STDIN>) && (@line = /^\s*(\d+)\s+(\d+)\s*$/)) {
      die "carr_read: invalid index $line[0]\n" if $line[0] <= $prev_index;
      $arr[$line[0]] = $line[1]; # let autovivify holes w/ undef
      $prev_index = $line[0];
   }

   die "carr_read: invalid format: $_\n" if defined $_;

   return @arr; # explicit return
}

=back
=cut

1;
