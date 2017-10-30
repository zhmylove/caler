#!/usr/bin/perl
# made by: kk

use POSIX;
use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use Data::Dumper;

my $_DEBUG = 0;

# avoid Math::Trig problems
sub pi { 3.141592653589793238462643383279 }

# print debug message if $_DEBUG
sub debug {
   print STDERR Dumper(@_) if $_DEBUG;
}

# Tabulates given function using given argument generator until it gives
# terminating (or greater, or undefined) value.
# 
# arg0: reference to function
# arg1: reference to argument generator
# arg2: terminator
sub tabulate($$$) {
  my ($f, $g, $t) = @_;
  debug $f, $g, $t;

  my $i;
  print "$i @{[&$f($i)]}\n" while (($i = &$g()) // $t) < $t;

  # Reset the generator
  &$g(0);
}

# Built-in functions wrappers. Needed because we can't take a reference to 'em.
sub sin($) {
  sin $_[0];
}

sub cos($) {
  cos $_[0];
}

# Other functions

# Generates a saw wave
sub saw($) {
  2 * ($_[0] - floor($_[0])) - 1;
}

# Generates meander (pulse)
sub meander_5_5($) {
  saw($_[0]) - saw($_[0] - 0.5);
}

# Generates meander (pulse)
sub meander_3_7($) {
  saw($_[0]) - saw($_[0] - 0.3);
}

# Generates triangle wave
sub triangle($) {
  ($_[0] -
    2 * floor(($_[0] + 1) / 2)
  ) *
  (-1) ** floor(($_[0] + 1) / 2);
}

# Argument generators

# Small nice metaprogramming from korg.
#
# Example of usage:
#
# generator { $state += 3 } 'f', +666;
#
# will be translated in next equivalent code:
#
# {
#   my $state = 666;
#   sub f(\$) {
#     return $state = 666 if defined $_[0];
#     $state += 3;
#   }
# }
#
# Thus, we have a python-like generators in Perl!
#
# Also, generators can be reseted to default value by calling them with defined
# first argument.
#
# arg0: code block, which operates with $state (as with closure) and yelds next
#       value when called
# arg1: generator's name, string. Shall be used as a function after creation.
# arg2: initial generator's value
no strict "refs";
our $state;
sub generator(&$$) {
  my ($code, $name, $init) = @_;

  # Create global reference to function with given $name
  *$name = sub {
    # Place _state, followed by the function name into string and eval() it
    # to create a closure for exactly this function, if it hasn't been created
    # before
    eval "our \$${name}_state = $init unless defined \$${name}_state";
    # Then, create variable in this scope with name $state, which are pointing
    # to closure
    eval "*state = *${name}_state";
    # Check for argument (used when there is need to reset the generator)
    return $::state = $init if defined $_[0];
    # Just call the given code, which can use $state, unique for it
    &$code;
  }
}
use strict "refs";

# Gives sequence of angles in radians.
#
# arg0: reset flag
#
# ret: next angle value
generator {
  (pi() * ($state++) ) / 180;
} 'even_rad', +0;

# Gives sequence of floating point numbers with step = 0.1
#
# arg0: reset flag
#
# ret: next value
generator {
  $state += 0.1;
} 'even', +0;

# main routine
#tabulate \&sin,         \&even_rad, 5*2*pi();
tabulate \&cos,         \&even_rad, 5*2*pi();
#tabulate \&saw,         \&even,     100;
#tabulate \&meander_5_5, \&even,     100;
#tabulate \&meander_3_7, \&even,     10;
#tabulate \&triangle,    \&even,     10;
# Thus, we can implement periodic functions, count their periods for some
# arguments and use tabulator to generate different periodic data. Also, we
# can replace &even with something more randomized, for example.
