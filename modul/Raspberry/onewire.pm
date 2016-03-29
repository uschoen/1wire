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
	$self->{'config'}{'tempDiv'}=(exists($ARGS{'tempDiv'})) ? $ARGS{'tempDiv'} : '0.3';
	$self->{'config'}{'path'}=(exists($ARGS{'path'})) ? $ARGS{'path'} : '/sys/bus/w1/devices/w1_bus_master1/';
	$self->{'config'}{'device_list'}=(exists($ARGS{'device_list'})) ? $ARGS{'device_list'} : {};
	$self->{'slaves'} = $self->{'config'}{'path'}. 'w1_master_slaves'; 
	
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
sub read_device
#	
#
#######################################################
{
	my $self=shift;
	my $deviceID = shift;
	my $filename = $self->{'config'}{'path'} . $deviceID . '/w1_slave';
	my $sensordata;
	
	if (!(open (DATEI, '<', $filename)))
	{ 
		$self->log("warning","Unable to open $filename: $!");
		return "**U**";
	}
  	$sensordata = join(' ',<DATEI>);
  	close (DATEI);

	if($sensordata =~ m/YES/)
    {
    	$sensordata =~ /t=(\D*\d+)/i;
    	$sensordata = ($1/1000);
    	$sensordata = sprintf "%.1f", $sensordata;
    	return ($sensordata);
    }else{
    	$self->log("info","CRC Invalid for $deviceID. $sensordata ");
    	return "**U**";
    }
}
####################################################### 
sub update_devices
#	
#
#######################################################
{
	my $self=shift;
	my %deviceIDs=%{$self->{'config'}{'device_list'}};
	for my $device_name (sort(keys %deviceIDs))
  	{
  		if ($deviceIDs{$device_name}{'enable'} ne "1")
  		{
  			$self->log("debug","$device_name is disable");
  			next;
  		}
    	my $value = sprintf("%6.2f",$self->read_device($deviceIDs{$device_name}{'device_id'}));
  		$self->log("debug","ID: ".$deviceIDs{$device_name}{'device_id'}." value : $value"); 
  		if ($value ne "**U**")
    	{
    		$self->log("debug","is ".$deviceIDs{$device_name}{'value'}." < ".($value-$self->{'config'}{'tempDiv'})." or ".$deviceIDs{$device_name}{'value'}." >".($value+$self->{'config'}{'tempDiv'}));
    		my $tempdiv=$self->{'config'}{'tempDiv'};
    		if (($deviceIDs{$device_name}{'value'} < ($value-$tempdiv)) or ($deviceIDs{$device_name}{'value'} > ($value+$tempdiv)))
    		{
    			$self->{'config'}{'device_list'}{$device_name}{'value'} = $value;
    			$self->log("debug",sprintf("set ne temperature for device %s %6.2f", $device_name, $value));
    			
    		}
    	}else{
 			$self->log("info","get no data from $device_name");
 		}
  	}
}
####################################################### 
sub scan_device_IDs
#	
#
#######################################################
{
	my $self=shift;
	my $found=0;
	if (!(open(INFILE, '<', $self->{'slaves'})))
	{
		$self->log("warning","cant not read ".$self->{'slaves'});
		return false;
	}
	$self->log("debug","check for new devices");
	my %deviceList=%{$self->{'config'}{'device_list'}};	
	while(<INFILE>)
    {
    	chomp;
		my $notfound=1;
    	foreach my $device_name (sort keys %deviceList)
    	{
    		if ($deviceList{$device_name}{'device_id'} eq $_)
    		{
    			$notfound=0;
    			$self->log("debug","found device $_ in device list");
    			if (!(exists($self->{'config'}{'device_list'}{$device_name}{value})))
    			{
    				$self->{'config'}{'device_list'}{$device_name}{value}=0;
    			}
    			if (!(exists($self->{'config'}{'device_list'}{$device_name}{enable})))
    			{
    				$self->{'config'}{'device_list'}{$device_name}{enable}=0;
    			}
    			last; 
    		}
		}
    	if ($notfound=="1"){
    		$self->log("info","add new device id $_ in devices list");
    		$self->{'config'}{'device_list'}{"N".$_}{value}="0";
    		$self->{'config'}{'device_list'}{"N".$_}{enable}=false;
    		$self->{'config'}{'device_list'}{"N".$_}{device_id}=$_;
    		$found=1;
    	}
    	
    }
    close(INFILE);
    $self->log("debug","update devices finish");
	return $found;
}
####################################################### 
sub get_config
#	
#
#######################################################
{
	my $self=shift;
	return $self->{'config'};
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
	if (!($self->{'log'}))
	{
		print $logdata->{'msg'}."\n";
		return;
	}
	($logdata->{'package'},$logdata->{'filename'},$logdata->{'line'}) = caller;
	$logdata->{'package'}=ref($self);
	$self->{'log'}->write($logdata);
	return 0;	
}