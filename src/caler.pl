#!/usr/bin/perl
# made by: KorG

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';
use Time::Local;
use CalerDB;

my $DB = CalerDB->new("/tmp/caler.db");
my %TemplateHash = ();
END{ $DB->save_data() };
$SIG{HUP} = sub { $DB->save_data() };

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
sub get_init_offset {
   my ($sec, $min, $hour) = localtime(time);
   my $offset = ($sec + $min * 60 + $hour * 3600);
   return $offset;
}
sub gather_data {
   my $counter = 0;
   my $step = 60;
   my $init_offset = get_init_offset();
   sleep($step - $init_offset % $step);
   my $border = $init_offset + $step - $init_offset % $step;
   $counter = $border;
   for(;;sleep($step)) {
      $DB->put("app1", "CPU", $counter, int(rand(101)));
      $counter += $step;
      $counter = 0 if $counter == (3600 * 24);
      approx_app_metric("app1", "CPU") if $counter == $border;
   }
}
sub put_template {
   my ($NAME, $ID) = @_;
   $TemplateHash{ $NAME }->{ ID } = $ID; 
}
sub get_templateID {
   my ($NAME) = @_;
   return $TemplateHash{ $NAME }->{ ID }; 
}
sub start_vm {
   my ($TEMPLATE_NAME) = @_;
   my $templateID = get_templateID($TEMPLATE_NAME);
   my $vmID = `onetemplate instantiate $templateID`;
   push(@{ $TemplateHash{ $TEMPLATE_NAME }->{ "VM_LIST" } }, $vmID);
}
sub stop_vm {
   my ($TEMPLATE_NAME) = @_;
   my $vmID = pop @{ $TemplateHash{ $TEMPLATE_NAME }->{"VM_LIST"} };
   $vmID =~ s/VM ID: //g;
   system("onevm", "terminate", $vmID);
}


#gather_data();
put_template("app1", 8);
start_vm("app1");
sleep(120);
stop_vm("app1");
use Data::Dumper;
print Dumper(\%TemplateHash);
#print Dumper($DB->get_DB());
