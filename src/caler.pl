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
use Data::Dumper;

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
sub get_deploy_id {
   my ($TEMPLATE_NAME) = @_;
   my @temp = ();
   my @deploy_ids = ();
   foreach my $vmID (@{ $TemplateHash{ $TEMPLATE_NAME }->{ "VM_LIST" } }) {
      @temp = `onevm show $vmID`;
      @temp = grep(/DEPLOY/, @temp);
      $temp[0] =~ s/DEPLOY ID +: //;
      push @deploy_ids, $temp[0];
   }
   return @deploy_ids;
}
sub gather_data {
   my ($TEMPLATE_NAME, $POLL_PERIOD) = @_;
   my $previous = 0;
   my $current = 0;
   my @temp = ();
   my $N = 0;
   my @deploy_ids = get_deploy_id($TEMPLATE_NAME);
   foreach my $deploy_id (@deploy_ids) {
      @temp = `virsh domstats --cpu-total $deploy_id`;
      @temp = grep(/time/, @temp);
      $temp[0] =~ s/\D//g;
      $previous += $temp[0];
      $N++;
   }
   sleep($POLL_PERIOD);
   foreach my $deploy_id (@deploy_ids) {
      @temp = `virsh domstats --cpu-total $deploy_id`;
      @temp = grep(/time/, @temp);
      $temp[0] =~ s/\D//g;
      $current += $temp[0];
   }
   $current = ($current - $previous)/($N * (10 ** 9));
   return $current;
}
sub store_data {
   my $counter = 0;
   my $step = 60;
   my $init_offset = get_init_offset();
   #sleep($step - $init_offset % $step);
   my $border = $init_offset + $step - $init_offset % $step;
   $counter = $border;
   $DB->put("app1", "CPU", $counter, gather_data("app1", $step - $init_offset % $step));
   print Dumper(\%TemplateHash);
   print Dumper($DB->get_DB());
   for(;;) {
      $counter += $step;
      $counter = 0 if $counter == (3600 * 24);
      approx_app_metric("app1", "CPU") if $counter == $border;
      $DB->put("app1", "CPU", $counter, gather_data("app1", $step));
      print Dumper(\%TemplateHash);
      print Dumper($DB->get_DB());
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
   $vmID =~ s/VM ID: //g;
   push(@{ $TemplateHash{ $TEMPLATE_NAME }->{ "VM_LIST" } }, $vmID);
   
}
sub stop_vm {
   my ($TEMPLATE_NAME) = @_;
   my $vmID = pop @{ $TemplateHash{ $TEMPLATE_NAME }->{"VM_LIST"} };
   system("onevm", "terminate", $vmID);
}
put_template("app1", 8);
start_vm("app1");
sleep(100); 
store_data();
