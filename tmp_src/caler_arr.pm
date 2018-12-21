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
our @EXPORT = qw( stub );

=head1 FUNCTIONS

=over 1

=item stub()
-- just a stub function
=cut
sub stub {
   print 1;
}

=back
=cut

1;
