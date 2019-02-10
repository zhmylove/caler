use lib qw( .. . );
use Test::More;

BEGIN{
   $ENV{_DEBUG} = 0;
}

use caler_fperiod;

sub triangle {
   my $amp = 64;
   my $period = $_[0];
   my $count = $period / 4;
   my $step = $amp / $count;
   my $i = -$step;
   my @rc;
   push @rc, $i+=$step for (0..$count);
   push @rc, $i-=$step for (0..2*$count);
   push @rc, $i+=$step for (1..$count);
   @rc = (@rc) x 1969;
   return \@rc;
}

our @solid_1 = (1,2,4,6,9,4,2,1,0,1,0,0,0,1,1);
our @solid_2 = (1,2,4,6,9,4,2,1,0,1,0,0,0,1,1,0,0,0);
our @solid_3 = (1,2,4,6,9,4,2,1,0,1,0,0,0,1,1,0,0,0,0);
our @solid_4 = qw( 0
0.257080551892155
0.496880137843737
0.70327941920041
0.862404227243338
0.963558185417193
0.999941720229966
0.969109128880456
0.873132979507516
0.718464793069126
0.515501371821464
0.277885925816587
0.0215909757260968
-0.236155320696896
-0.478027246135342
-0.687766159183973
-0.851273400935574
-0.957558007449271
-0.999475522827284
-0.97420824985281
-0.883454655720154
-0.733315200995658
-0.533882266391646
-0.298561742493597
);

my $count = 8192;
my $rnd = 0.05;

eval "our \@rnd_$_=(\@$_) x $count;for(\@$_){\$_*=3;\$_+=rand($rnd);
\$_-=$rnd/2;}" for grep /^solid_/, keys %{main::};

my @a = (
   [ [1, 2, 3], 'short', 'too short' ],
   (map {eval "[[(\@$_) x $count],0+\@$_,'$_']"} sort {$a cmp $b} (
      grep /^solid_/, keys %{main::})),
   (map {eval "[[\@rnd_$_],0+\@$_,'rnd_$_']"} sort {$a cmp $b} (
      grep /^solid_/, keys %{main::})),
   #map {[ triangle($_), $_, "triangle $_" ]} (30..33, 72..75, 181),
   #map {[ [(map $_*5,1..$_) x 2000], $_, "clean $_" ]} (3..12),
);

sub run {
   my $rc = -1;
   eval { $rc = caler_fperiod(@{$_[0]}); };
   if ($_ = $@) {
      return "short" if /^Too short/;
      return "uncaught exception";
   }
   return $rc;
}

for (@a) {
   my $aref = $_->[0]; # due to Test::More internals
   my $text = $_->[1];
   my $name = $_->[2];
   is(run($aref), $text, $name);
}

done_testing();
