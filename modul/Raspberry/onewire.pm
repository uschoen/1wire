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
	$self->log("info","onewire build complete");
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
    	$self->log("info","wire modules loaded");
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
	my %deviceList=%{$self->{'device_list'}};	
	while(<INFILE>)
    {
    	chomp;
    	$self->log("debug","found device: $_"); 
    	my $notfound=1;
    	foreach my $device_id (sort keys %deviceList)
    	{
    		print Dumper($device_id);
    		
    		
    	}
    	if ($notfound=="1"){
    		$self->log("info","add device id $_ in devices list");
    		$self->{'device_list'}{$_}{'value'}=0;
    	}
    	
    }
    close(INFILE);
    $self->log("debug","update devices finish");
	return true;
 }
 ####################################################### 
sub log
#	
#
#######################################################
{
	my $self= shift;
	my $logdata->{'level'}=lc(shift ||"unkown");
	$logdata->{'msg'}=shift	||"unkown msg";
	if (!($self->{'log'})){
		#######
		print $logdata->{'msg'}."\n";
		#######
		return;
	}
	($logdata->{'package'},$logdata->{'filename'},$logdata->{'line'}) = caller;
	$logdata->{'package'}=ref($self);
	$self->{'log'}->write($logdata);
	return 0;	
}