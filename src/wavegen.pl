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

my $_DEBUG = 1;

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
# args: arg0's arguments
sub tabulate($$$;@) {
  my ($f, $g, $t) = @_;
  debug $f, $g, $t;

  @_ = splice @_, 3;

  my $i;
  print "$i @{[&$f($i, @_)]}\n" while (($i = &$g()) // $t) < $t;

  # Reset the generator
  &$g(0);
}

# Built-in functions wrappers. Needed because we can't take a reference to 'em.
#- Generates sin
sub sin($;@) {
  my $T = $_[1]; # Period
  sin $_[0] * 2*pi() / $T;
}

#- Generates cos
sub cos($;@) {
  my $T = $_[1]; # Period
  cos $_[0] * 2*pi() / $T;
}

# Other functions

#- Generates a saw wave
sub saw($;@) {
  # TODO: handle period
  2 * ($_[0] - floor($_[0])) - 1;
}

#- Generates meander (pulse)
sub meander_5_5($;@) {
  # TODO: handle period
  saw($_[0]) - saw($_[0] - 0.5);
}

#- Generates meander (pulse)
sub meander_3_7($;@) {
  # TODO: handle period
  saw($_[0]) - saw($_[0] - 0.3);
}

#- Generates triangle wave
sub triangle($;@) {
  # TODO: handle period
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
# generator { $state += 3 } 'f', 666;
#
# will be translated in next equivalent code:
#
# {
#   my $state = 666;
#   sub f(;$) {
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
sub generator(&$;$) {
  my ($code, $name, $init) = @_;
  $init //= 0;

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
} 'even_rad';

# Gives sequence of floating point numbers with step = 0.1
#
# arg0: reset flag
#
# ret: next value
generator {
  $state += 0.1;
} 'even';


### main routine

my $USAGE = "Usage: $0 <wave> [-p<period>] [-s<stop_time>]";
die $USAGE unless @ARGV >= 1;

our %CFG = (
  wave   => shift @ARGV, # wave type (sin, saw, etc)
  period => 1,           # wave period (TODO: parametrize waves)
  stop   => 32,          # tabulating stop time
);

for (@ARGV) {
  given ($_) {
    $CFG{period} = $1 when /-p(\d+)/;
    $CFG{stop}   = $1 when /-s(\d+)/;
    default      { die $USAGE; }
  }
}

die 'Period must be grater than 0' unless (
  $CFG{period} = sprintf '%f', $CFG{period}) > 0;

die 'Stop time must be grater than 0' unless (
  $CFG{stop} = sprintf '%f', $CFG{stop}) > 0;

open THIS, '<', $0 or die $!;
my %waves = ();
my $previous = '';
for (<THIS>) {
  chomp;
  $waves{s/sub ([^(]+).*/$1/r} = 1 if ($previous =~ /^\#- Generates/);
  $previous = $_;
}
close THIS;

die "Waves:\n\t" . join "\n\t", keys %waves unless defined $waves{$CFG{wave}};

eval "tabulate \\&$CFG{wave}, \\&even, $CFG{stop}, $CFG{period}";

#tabulate \&sin,         \&even, 5*2*pi(), 5;
#tabulate \&cos,         \&even_rad, 5*2*pi();
#tabulate \&saw,         \&even,     100;
#tabulate \&meander_5_5, \&even,     100;
#tabulate \&meander_3_7, \&even,     10;
#tabulate \&triangle,    \&even,     10;
# Thus, we can implement periodic functions, count their periods for some
# arguments and use tabulator to generate different periodic data. Also, we
# can replace &even with something more randomized, for example.
