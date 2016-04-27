#!/usr/bin/perl -w
$| = 1;

package Gateway::onewire;
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
	$self->set_config($arg_hash);
	if (!($self->check_modules()))
	{
		return false;
	}
	$self->{connectors}=();
	$self->{connected_device}={};
	$self->{current_device_change}=false;
	$self->log("info","onewire build complete");
	return $self;
}  
####################################################### 
sub set_config
#	
#
#######################################################
{
	my $self= shift;
	my $ARGS_ref= shift;
	my %ARGS=%{$ARGS_ref};
	### Config settings
	$self->{'log'}=(exists($ARGS{'log'})) ? $ARGS{'log'} : '';
	$self->{'config'}{'tempDiv'}=(exists($ARGS{'tempDiv'})) ? $ARGS{'tempDiv'} : '0.3';
	$self->{'config'}{'path'}=(exists($ARGS{'path'})) ? $ARGS{'path'} : '/sys/bus/w1/devices/w1_bus_master1/';
	$self->{'config'}{'device_list'}=(exists($ARGS{'device_list'})) ? $ARGS{'device_list'} : {};
	$self->{'config'}{'slaves'} = $self->{'config'}{'path'}. 'w1_master_slaves'; 
	$self->{'config'}{'temp_configfile'}=(exists($ARGS{'temp_configfile'})) ? $ARGS{'temp_configfile'} : '/temp/onewire_config.xml';
	$self->log("dump","config: ".Dumper ($self->{'config'}));	
	$self->update_device_list();
	$self->check_for_unavailable_device();
	$self->import_device_config();
	if ($self->{current_device_change})
	{
		$self->save_configfile($self->{connected_device});
	}
	### Vars
	$self->log("info","onewired load new config complete");
}
####################################################### 
sub import_device_config
#	
#
#######################################################
{
	my $self=shift;
	
	$self->log("debug","import device config");
	my %devices=%{$self->{connected_device}};
	foreach my $device_name (sort keys %devices)
    {
    	if (!(exists($self->{'config'}{'device_list'}{$device_name})))
    	{
    		##### hardware vorhanden und nicht im config file
    		if ($self->{connected_device}{$device_name}{enable})
    		{
    			$self->{connected_device}{$device_name}{enable}=false;
    			$self->log("info","can not find device $device_name in config file, disable device");
    		}else{
    			$self->log("info","can not find device $device_name in config file, device is disable");
    		}
    		next;
    	}
    	$self->log("debug","import data from config file for device $device_name");
    	
    	my %old_device=%{$self->{connected_device}{$device_name}};
    	
    	$self->{connected_device}{$device_name}=$self->{'config'}{'device_list'}{$device_name};
    	### timestamp
    	$self->{connected_device}{$device_name}{timestamp}=$old_device{timestamp};
    	
    	###  value
    	$self->{connected_device}{$device_name}{value}=$old_device{value};
    	
    	### device name
    	if (!(exists($self->{connected_device}{$device_name}{device_name})))
    	{
    		$self->{connected_device}{$device_name}{device_name}=$device_name;
    	}
    	### device enable
    	if (!(exists($self->{connected_device}{$device_name}{enable})))
    	{
    		$self->{connected_device}{$device_name}{enable}=false;
    	}
    	### device available
    	if (!(exists($self->{connected_device}{$device_name}{available})))
    	{
    		$self->{connected_device}{$device_name}{available}=true;
    	}
    	### device id
    	$self->{connected_device}{$device_name}{device_id}=$old_device{device_id};
    }
    $self->log("dump","after update device from config:".Dumper($self->{connected_device})); 
}	
####################################################### 
sub update_device_list
#	
#
#######################################################
{
	my $self= shift;
	
	$self->log("debug","update devices list");
	
	$self->{current_device_change}=false;	
	$self->clear_device_available_flag();
	$self->log("debug","reading ".$self->{'config'}{'slaves'});
	
	if (!(open(INFILE, '<', $self->{'config'}{'slaves'})))
	{
		$self->log("warning","cant not read ".$self->{'config'}{'slaves'});
		return false;
	}
	$self->log("debug","check connected devices");
	while(<INFILE>)
    {
    	chomp;
    	my $device_name="N".$_;
    	if (exists($self->{connected_device}{$device_name})){
    		$self->log("debug","device id : $_ device name: $device_name is exists, and set to available");
    		$self->{connected_device}{$device_name}{available}=true;
		}else{
			$self->log("info","and new device id : $_ device name: $device_name");
			$self->{connected_device}{$device_name}=$self->add_new_device($_);
			$self->{current_device_change}=true;
			$self->log("info","device list is change");
		}
		$self->log("dump","device list:".Dumper($self->{connected_device})); 
    	
    }
    close(INFILE);
    $self->log("debug","update devices finish");
	return ;
}
####################################################### 
sub check_for_unavailable_device
#	
#
#######################################################
{
	my $self=shift;
	
	$self->log("debug","check for unavailable devices");
	 
	foreach my $device_name (sort keys %{$self->{connected_device}})
    {
    	if (!($self->{connected_device}{$device_name}{available}))
    	{
    		$self->log("info","deleted device $device_name from connect device list");
    		delete ($self->{connected_device}{$device_name});
    		$self->{current_device_change}=true;
    		$self->log("info","device list is change");
    	}	
    }
}
####################################################### 
sub save_configfile
#	
#
#######################################################
{
	my $self=shift;
	my $config=shift;
	
	$self->log("debug","writing config file: ".$self->{config}{temp_configfile});
	my $xs = XML::Simple->new();
	my $xml = $xs->XMLout($config,noattr => 1, XMLDecl => "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>");
	if (open(FH, ">",$self->{config}{temp_configfile}))
	{ 
			FH->autoflush(1);
			print FH $xml;
			close FH;
			$self->log("info","write successful new config to: ".$self->{config}{temp_configfile});
	}else{
			$self->log("error","can not write to ".$self->{config}{temp_configfile});
	}
	
}
####################################################### 
sub clear_device_available_flag
#	
#
#######################################################
{
	my $self=shift;
	
	$self->log("debug","disable device available flag");
	
	foreach my $device_name (sort keys %{$self->{connected_device}})
    {
    	$self->{connected_device}{$device_name}{available}=false;
    	$self->log("debug","disable device $device_name");
    }
}	
####################################################### 
sub add_new_device
#	
#
#######################################################
{
	my $self=shift;
	my $device_id=shift;
	my %device;
	
	my $device_name="N".$device_id;
	$self->log("info","add new device with id: $device_id");
	
	$device{value}="0";
	$device{device_name}=$device_name;
    $device{enable}=false;
    $device{available}=true;
    $device{device_id}=$device_id;
    $device{timestamp}=time();
    return \%device;
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
sub push_connector
#	
#
#######################################################
{
	my $self= shift;
	my $connector=shift;
	push(@{$self->{connectors}},$connector);
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
sub read_devices
#	
#
#######################################################
{
	my $self=shift;
	
	$self->log("dump","old device values:".Dumper($self->{connected_device})); 
	
	for my $device_name (sort(keys %{$self->{connected_device}}))
  	{
  		if ($self->{connected_device}{$device_name}{'enable'} ne "1")
  		{
  			$self->log("debug","device name $device_name is disable");
  			next;
  		}
    	my $value =$self->read_device($self->{connected_device}{$device_name}{'device_id'});
  		$self->log("debug","read ID: ".$self->{connected_device}{$device_name}{'device_id'}." value : $value"); 
  		if ($value ne "**U**")
    	{
    		$value =sprintf("%.2f",$value);
    		my $tempdiv=$self->{'config'}{'tempDiv'};
    		my $oldtemp=$self->{connected_device}{$device_name}{'value'};
    		$self->log("debug","is: ".$oldtemp." < ".($value-$tempdiv)." or is:".$oldtemp." >".($value+$tempdiv));
    		if (($oldtemp < ($value-$tempdiv)) or ($oldtemp > ($value+$tempdiv)))
    		{
    			$self->{connected_device}{$device_name}{'value'} = $value;
    			$self->{connected_device}{$device_name}{'timestamp'}=time();
    			$self->log("info","set temperature for device  $device_name  $value");
    			foreach my $connector (@{$self->{connectors}})
  				{
  					$self->log("info","push sensor data to connector $connector");
 					$connector->send_data($self->{connected_device}{$device_name});
  				}
    			
    		}else{
    			$self->log("debug","no change for value");
    		}
    	}else{
 			$self->log("warning","get no data from $device_name disable device");
 			$self->{connected_device}{$device_name}{enable} = 0;
 			
 		}
  	}
  	$self->log("dump","new device values:".Dumper($self->{connected_device})); 			
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