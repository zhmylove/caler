use lib qw( .. . );
use Test::More;

use caler_arr;

sub fake_stdin {
   close STDIN;
   open my $fh, "<", \$_[0] or die $!;
   *STDIN = $fh;
}

fake_stdin join "\n", map {"$_ $_"} 1..5;
is_deeply([carr_read()], [undef, 1, 2, 3, 4, 5], 'simple integer');

fake_stdin join "\n", map {($_ + 0.25) . " $_"} 1..5;
is_deeply([carr_read()], [undef, 1, 2, 3, 4, 5], 'simple floating point');

fake_stdin join "\n", "2 3", "4 3", "6 3";
is_deeply([carr_read()], [undef, undef, 3, undef, 3, undef, 3], 'holes');

fake_stdin join "\n", "4 5", "4 3", "4 8";
is_deeply([carr_read()], [undef, undef, undef, undef, 16/3], 'approximation');

done_testing();
