#!/usr/bin/perl

package psum;

use strict;
use warnings;
use v5.10;

sub new {
    bless [], $_[0];
}

# arg0: self
# arg1: element to add
sub add {
    my $self = $_[0];
    push @{$self}, $_[1] + ($self->[@{$self} - 1] // 0);
}

# arg0: self
# arg1: count of elements to shift
sub shift {
    my ($self, $to) = ($_[0], $_[1] // 1);
    shift @{$self}, $to;
}

# arg0: self
# arg1: right (inclusive) border of summation (default is end of array)
# arg2: left (exclusive) border of summation (default is -1)
# ret: sum between left and right borders of filled array
sub sum {
    my ($self, $last, $first) = @_;
    return $self->[@{$self} - 1] unless defined $last;
    return $self->[$last]        unless defined $first;
    return $self->[$last] - $self->[$first];
}

1;
