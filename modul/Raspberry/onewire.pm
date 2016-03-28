#!/usr/bin/perl -w
$| = 1;

package Raspberry::onewire;
use strict;
use warnings;
use Data::Dumper;  


use constant true => 1;
use constant false => 0;

#######################################################
sub new
#	Vars=%config
#	
#
#######################################################
{
	my $class=shift;
	my $arg_hash = (ref($_[0]) eq 'HASH') ? $_[0] : {@_};
	
	if (!($_[0])){
		print "no args given\n\r";
		return false;
	}
	
	my $self={};
	bless $self,$class;
	$self->init_args($arg_hash);
	if (!($self->check_modules()))
	{
		return false;
	}
	$self->log("info","onewired build complete");
	return $self;
}  
####################################################### 
sub init_args
#	
#
#######################################################
{
	my $self= shift;
	my $ARGS_ref= shift;
	my %ARGS=%{$ARGS_ref};
	
	$self->{'log'}=(exists($ARGS{'log'})) ? $ARGS{'log'} : '';
	$self->{'gpio_pin'}=(exists($ARGS{'gpio_pin'})) ? $ARGS{'gpio_pin'} : '4';
	$self->{'intervall'}=(exists($ARGS{'intervall'})) ? $ARGS{'intervall'} : '30';
	$self->{'tempDiv'}=(exists($ARGS{'tempDiv'})) ? $ARGS{'tempDiv'} : '0.3';
	$self->{'path'}=(exists($ARGS{'path'})) ? $ARGS{'path'} : '/sys/bus/w1/devices/w1_bus_master1/';
	$self->{'device_list'}=(exists($ARGS{'device_list'})) ? $ARGS{'device_list'} : {};
	$self->{'slaves'} = $self->{'path'}. 'w1_master_slaves'; 
	
	$self->log("info","onewired load new config complete");
	
}
####################################################### 
sub check_modules
#	
#
#######################################################
{
	my $self=shift;
	my $mods;
	
	# alle geladenen Module stehen in der Datei /proc/modules
	if (!(open (DATEI, '<', '/proc/modules'))) 
    {
    	$self->log("error","can not read /proc/modules");
		return false;
    }
            
  	$mods = join(' ',<DATEI>);
  	close (DATEI);
  	if ($mods =~ /w1_gpio/ && $mods =~ /w1_therm/)
    {
    	$self->log("info","w1 modules already loaded");
    	return true;
    }else
    {
   		$self->log("error","no modules load, please load  w1 modules");
    	$self->log("error","do kernel <3.1: sudo modprobe w1-gpio");
    	$self->log("error","do: sudo modprobe w1-therm ");
    	$self->log("error","and insert in /etc/modules");
    	$self->log("error","do kernel >3.1: nano /boot/config.txt");
    	$self->log("error","insert: dtoverlay=w1-gpio-pullup,gpiopin=4,extpullup=on");
    	return false;
    }
}
####################################################### 
sub get_device_IDs
#	
#
#######################################################
{
	my $self=shift;

	if (!(open(INFILE, '<', $self->{'slaves'})))
	{
		$self->log("warning","cant not read ".$self->{'slaves'});
		return false;
	}
	$self->log("debug","check for new devices");
	my %sensor=%{$self->{'device_list'}};	
	while(<INFILE>)
    {
    	chomp;
    	$self->log("debug","found device: $_"); 
    	my $notfound=1;
    	foreach my $sensor_name (sort keys %sensor) {
    		if ($sensor{$sensor_name}{'sensor_id'} eq $_){
    			$notfound=0;
    			if (exists($self->{'deviceIDs'}{$sensor{$sensor_name}{'ise_id'}})){
					last;
				}
				$self->log("info","found sensor in device list device_id:$_  ise_id:".$sensor{$sensor_name}{'ise_id'}." enable:".$sensor{$sensor_name}{'enable'});
				$self->{'deviceIDs'}{$sensor{$sensor_name}{'ise_id'}} = $_;
    			$self->{'temperatures'}{$sensor{$sensor_name}{'ise_id'}}=0;
    			$self->{'device_enable'}{$sensor{$sensor_name}{'ise_id'}}=$sensor{$sensor_name}{'enable'};
    		}
    	}
    	if ($notfound=="1"){
    		$self->log("info","device id $_ not in devices list");
    	}
    	
    }
    close(INFILE);
    $self->log("debug","update devices finish");
	return true;
 }