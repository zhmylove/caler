#!/usr/bin/perl
# made by: KorG

package CalerDB;

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use Storable;

my $FILE = "";
my %DB = ();
my $instance;

sub new {
   my $self = shift;

   # sigletone
   if ($FILE ne "") {
      die "Internal error" unless $instance;
   } else {
      $FILE = shift;
      store({}, $FILE) unless -r $FILE;
      %DB = %{retrieve $FILE};
      $instance = bless {}, $self;
   }

   return $instance;
}

# persist to disk
sub save_data {
   return 0 if $FILE eq "";

   store(\%DB, $FILE) and return 1;

   return 0;
}

# put ( APP, METRIC, TIME, VALUE )
sub put {
   my ($_, $APP, $METRIC, $TIME, $VALUE, $COUNT) = @_;

   return 0 if ($VALUE // "") eq "";

   push(@{ $DB{ $APP }->{ $METRIC }->{ $TIME } }, $VALUE);
   push(@{ $DB{ $APP }->{ $METRIC }->{ $TIME } }, $COUNT);

}

# override approx values
sub put_approx {
   my ($_, $APP, $METRIC, $TIME, $VALUE, $COUNT) = @_;

   return 0 if ($VALUE // "") eq "";

   push (@{ $DB{ approx }->{ $APP }->{ $METRIC }->{ $TIME } }, $VALUE);
   push (@{ $DB{ approx }->{ $APP }->{ $METRIC }->{ $TIME } }, $COUNT);
}

# get_day ( APP, METRIC )
sub get_day {
   my ($_, $APP, $METRIC) = @_;

   return 0 if ($METRIC // "") eq "";

   return $DB{ $APP }->{ $METRIC };
}

# get_approx_day ( APP, METRIC )
sub get_approx_day {
   my ($_, $APP, $METRIC) = @_;

   return 0 if ($METRIC // "") eq "";

   return $DB{ approx }->{ $APP }->{ $METRIC } // {};
}

# get_time ( APP, METRIC, TIME )
sub get_time {
   my ($_, $APP, $METRIC, $TIME) = @_;

   return 0 if ($TIME // "") eq "";

   return $DB{ $APP }->{ $METRIC }->{ $TIME };
}
sub get_approx_time {
   my ($_, $APP, $METRIC, $TIME) = @_;

   return 0 if ($TIME // "") eq "";

   return $DB{ approx }->{ $APP }->{ $METRIC }->{ $TIME };
}

sub get_N { return $DB{ N } // ($DB{ N } = 1); }

sub set_N { return $DB{ N } = $_[1] // return 0; }

sub inc_N { return set_N('', get_N() + 1); }

# for debug purposes
sub get_DB { return \%DB; }

1;
