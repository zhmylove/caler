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
use POSIX;

=encoding utf-8

=head1 NAME

B<caler> -- auto-scaler for OpenNebula

=head1 SYNOPSIS

   su - oneadmin
   ./caler

=head1 DESCRIPTION

The B<caler> utility performs auto-scaling routines for OpenNebula cloud.
It based on history of usage of each template and uses some other
algorithmistic improvements to manage VMs count. 

=head1 FUNCTIONS

=over 4

=cut

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
   my $count = 0;

   while (my($key, $value) = each %current) {
      $_ = ((${ $previous{$key} // [] }[0] // 0) * ($N - 1) + ${ $current{$key} }[0]) / $N;
      $count = ((${ $previous{$key} // [] }[1] // 0) * ($N - 1) + ${ $current{$key} }[1]) / $N; 
      $DB->put_approx("app1", "CPU", $key, $_, $count);
   }

   $DB->inc_N();
}

=item get_init_offset()

   ret: time offset of ./caler start from the beginning of the day

=cut

sub get_init_offset {
   my ($sec, $min, $hour) = localtime(time);
   #my $offset = ($sec + $min * 60 + $hour * 3600);
   my $offset = ($sec + $min * 60);
   return $offset;
}

=item get_deploy_ids()

   ret: ARRAY of deploy ids
   arg0: template

This function iterates through VMs from I<%TemplateHash> and made with I<template>.
For each VMs it asks I<ONE> for deploy id of the VM.
A list of deploy ids returned as well.

=cut

sub get_deploy_ids {
   my ($TEMPLATE_NAME) = @_;
   my @deploy_ids = ();
   foreach my $vmID (@{ $TemplateHash{ $TEMPLATE_NAME }->{ "VM_LIST" } }) {
      my ($id) = `onevm show $vmID` =~ m{DEPLOY ID +: (one.+?) *\n}s;
      push @deploy_ids, $id if defined $id;
   }
   return @deploy_ids;
}

sub get_cpu_time {
   my $TEMPLATE_NAME = $_[0];
   my $N = 0;
   my $time = 0;
   my @deploy_ids = defined $_[1] ? @{ $_[1] } : get_deploy_ids($TEMPLATE_NAME);
   foreach my $deploy_id (@deploy_ids) {
      my ($temp) = `virsh -c qemu:///system domstats --cpu-total $deploy_id` =~ m{time=(\d+)}s;
      $time += $temp // 0;
   }
   return ($time, $#deploy_ids + 1, @deploy_ids);
}

=item sum_list()

   ret: sum of arguments
   arg0 .. : any number

=cut

sub sum_list { eval join "+", map { $_ // 0 } @_ }

=item correlation()

   ret: deviation from mean values (recent history)
   arg0: time offset of current time
   arg1: time step
   arg2: period for looking back

This function calculates average deviation of characteristics for some period of time.

=cut

sub correlation {
   my ($START, $STEP, $CORR_DURATION) = @_;
   my @cpucorr = ();
   my @vmnumber = ();
   my $n = $CORR_DURATION / $STEP;
   my ($currentcpu, $historicalmeancpu, $historicalmeanvm) = (0);
   $cpucorr[$n] = 0;
   $vmnumber[$n] = 0;
   for (my $count = $n; $count >= 0; $count--) {
      $currentcpu = ${ $DB->get_time("app1", "CPU", $START) }[0]; 
      $historicalmeancpu = ${ $DB->get_approx_time("app1", "CPU", $START) }[0];
      $_ = abs $currentcpu - $historicalmeancpu;
      pop @cpucorr;
      unshift @cpucorr, $_;
      $START -= $STEP;  
      $START = 3600 + $START if $START < 0;
   }
   return 1/($n + 1) * sum_list(@cpucorr);
}

sub get_vm_number_prediction {
   my ($START, $STEP, $PREDICTION_STEP) = @_;
   my @vmnumber = ();
   my $n = $PREDICTION_STEP / $STEP;
   my $max = 0;
   for (my $count = $n; $count >= 0; $count--) {
      @_ = @{ $DB->get_approx_time("app1", "CPU", $START) };
      $_ = $_[0] * $_[1];
      print "$_\n";
      $max = $_ if $_ > $max;
      $START += $STEP;
      $START = 0 if $START == 3600;
   }
   $_ = ceil($max / 65);
   return $_;
}

sub gather_data {
   my ($TEMPLATE_NAME, $POLL_PERIOD) = @_;
   my ($previous, $N, @temp) = get_cpu_time($TEMPLATE_NAME);
   sleep($POLL_PERIOD);
   my ($current) = get_cpu_time($TEMPLATE_NAME, \@temp);
   $current = ($current - $previous)/($N * $POLL_PERIOD * (10 ** 9)) * 100;
   return ($current, $N);
}

sub store_data {
   my $counter = 0;
   my $step = 60; #seconds between history marks
   my ($util, $count);
   my ($corell, $vmnumber);
   my $init_offset = get_init_offset();
   my $correlation_threshold = 10; #avg deviation in percentages
   my $border = $init_offset + $step - $init_offset % $step;
   my $prediction_period = 600;
   my $prediction_step = (int(($prediction_period / 3) / 60)) * 60;
   my $first_day = 1;
   $counter = $border;
   $DB->put("app1", "CPU", $counter, gather_data("app1", $step - $init_offset % $step));
   print Dumper(\%TemplateHash);
   print Dumper($DB->get_DB());
   for(;;) {
      $counter += $step;
      $counter = 0 if $counter == 3600;
      if ($counter == $border) {
         approx_app_metric("app1", "CPU");
         $first_day = 0;
      }
      $DB->put("app1", "CPU", $counter, ($util, $count) = gather_data("app1", $step));
      unless ($first_day) {
         $corell = correlation($counter, $step, 1800);
         if ($corell <= $correlation_threshold) {
            $vmnumber = get_vm_number_prediction($counter, $step, $prediction_step);
            if ( ($_ = $count - $vmnumber) >= 0) { 
               stop_vm("app1") while $_--;
            } else { 
               start_vm("app1") while $_++;
            }

            my $count = $prediction_period / $step;
            my $prediction_step_counter = 0;
            for ($counter += $step; $count > 0 ; $count--) {
               $counter = 0 if $counter == 3600;
               approx_app_metric("app1", "CPU") if $counter == $border;
               $DB->put("app1", "CPU", $counter, ($util, $count) = gather_data("app1", $step));
               $prediction_step_counter += $step;
               if ($prediction_step_counter == $prediction_step) {
                  $vmnumber = get_vm_number_prediction($counter, $step, $prediction_step);
                  if ( ($_ = $count - $vmnumber) >= 0) { 
                     stop_vm("app1") while $_--;
                  } else { 
                     start_vm("app1") while $_++;
                  }
                  $prediction_step_counter = 0;
               }
               $counter += $step;
            }
            $counter -= $step;
         } else {
            start_vm("app1") if $util > 90;
            stop_vm("app1") if $util < 40 and $count > 1;
         }
      } else {
         start_vm("app1") if $util > 90;
         stop_vm("app1") if $util < 40 and $count > 1;
      }
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
   return $vmID;
   
}

sub stop_vm {
   my ($TEMPLATE_NAME) = @_;
   my $vmID = pop @{ $TemplateHash{ $TEMPLATE_NAME }->{"VM_LIST"} };
   system("onevm", "terminate", $vmID);
   return $vmID;
}

=back

And the program consists of:
   some temporary code ...

=cut

put_template("app1", 8);
start_vm("app1");
sleep(60);
store_data();
#$\="\n";
#print for sort keys %{ $DB->get_approx_day("app1", "CPU") };

