#!/usr/bin/perl
# made by: KorG

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use CalerDB;

my $DB = CalerDB->new("/tmp/caler.db");

END{ $DB->save_data() };

$DB->put("app1", "CPU", 0, 11);
$DB->put("app1", "CPU", 1, 22);
$DB->put("app1", "CPU", 2, 33);
$DB->put("app1", "CPU", 3, 22);
$DB->put("app1", "CPU", 4, 44);
$DB->put("app1", "CPU", 5, 55);
$DB->put("app1", "CPU", 6, 66);
$DB->put("app1", "CPU", 7, 77);
$DB->put("app1", "CPU", 8, 88);
$DB->put("app1", "CPU", 9, 99);
$DB->put("app1", "CPU", 10, 100);
$DB->put("app1", "CPU", 11, 99);
$DB->put("app1", "CPU", 12, 66);
$DB->put("app1", "CPU", 13, 35);
$DB->put("app1", "CPU", 14, 45);
$DB->put("app1", "CPU", 15, 55);
$DB->put("app1", "CPU", 16, 34);
$DB->put("app1", "CPU", 17, 54);
$DB->put("app1", "CPU", 18, 75);
$DB->put("app1", "CPU", 19, 85);
$DB->put("app1", "CPU", 20, 99);
$DB->put("app1", "CPU", 21, 100);
$DB->put("app1", "CPU", 22, 75);
$DB->put("app1", "CPU", 23, 35);

sub approx_app_metric {
   my ($APP, $METRIC) = @_;

   return 0 if ($METRIC // "") eq "";

   my %previous = %{ $DB->get_approx_day($APP, $METRIC) };
   my %current = %{ $DB->get_day($APP, $METRIC) };
   my $N = $DB->get_N();

   while (my($key, $value) = each %current) {
      $_ = (($previous{$key} // 0) * ($N - 1) + $current{$key}) / $N;
      $DB->put_approx("app1", "CPU", $key, $_);
   }

   $DB->inc_N();
}

approx_app_metric("app1", "CPU");

use Data::Dumper;
print Dumper($DB->get_DB());
