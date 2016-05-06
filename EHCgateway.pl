#!/usr/bin/perl -w 
$| = 1;

#!/usr/bin/perl

################################################################
#
#  Copyright notice
#
#  (c) 2005-2016
#  Copyright: ullrich schoen (uschoen at johjoh dot de)
#  All rights reserved
#
#  This script free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  This copyright notice MUST APPEAR in all copies of the script!
#
#  Homepage:
# http://blog.johjoh.de/onewire-temperatur-sensoren-fuer-die-homematic-ccu-raspberry/
# http://blog.johjoh.de/onewire-temperatur-sensoren-fuer-die-homematic-ccu-raspberry-software-loesung/
# http://blog.johjoh.de/
#
# $Id: EHCGateway.pl  2016-01-01 08:43:05Z ullrich schoen $

####### include Perl module 
use strict;
use warnings;
use POSIX qw(setuid setgid);
use Getopt::Long qw(GetOptions);
use Data::Dumper;
use XML::Simple;
use FindBin qw($Bin);
use lib "$Bin/modul";

####### constant 
use constant true => 1;
use constant false => 0;

####### Globale variable
use vars qw(%SYS);				# Systems configuration
our $CONFIGFILE="";		# config file name
use vars qw($DAEMON);				# run as damon ?
use vars qw($LOG);				# Log intance
use vars qw(%CONNECTORS);			# connectors objects
use vars qw(%GATEWAYS);			# connectors objects
use vars qw(%DATASOURCE);			# sensor kodule

###### Default value for variables
$CONFIGFILE="/usr/local/easyHC/conf/config.xml";
$DAEMON="UNKOWN";			

####### If started as root, and there is a ehcuser user in the /etc/passwd, su to it
su_to_ehcuser();

####### get start options
GetOptions('configfile=s' => \$CONFIGFILE,
			'daemon=s'   => \$DAEMON)
or die "Usage: $0 --configfile [absolute path to the configfile] --daemon [true||false]\n";

####### read config file
%SYS = %{(read_configfile($CONFIGFILE))};

####### switch dto root dir "/"
chdir "/";
####### include custommer module
use MultiLogger::Dispatcher;
use Raspberry::onewire;

####### overwirte config with options
$SYS{'daemon'}=$DAEMON if (($DAEMON eq "true") or ($DAEMON eq "false"));

####### runs as daemon ?
&daemonize() if (($SYS{'daemon'} eq "true"));

####### set signal handle
$SIG{'PIPE'} = \&SHUTDOWN;
$SIG{'INT'}  = \&SHUTDOWN;
$SIG{'TERM'} = \&SHUTDOWN;
$SIG{'HUP'}  = \&SHUTDOWN;
####### add logging

if (exists( $SYS{"logging"})) {
	my %PARMS=%{$SYS{"logging"}};
	$PARMS{path}=$SYS{path};
	if (!($LOG =MultiLogger::Dispatcher->new(%PARMS)))
	{
    	print "can not create logging\n";
		exit(0);
    }
}else{
	print "can not create logging, no configuration found!\n";
}
########

&log("info","start up $0 with PID " . $$ );	

&build_gateways();
&build_connectors();
&log("debug","main lopp start");
	
######## main loop
my $sleeptime=1;
while (1)
{
	%SYS = %{(&read_configfile($CONFIGFILE))};
	for my $gateway_name (sort(keys %GATEWAYS))
  	{
			if ($GATEWAYS{$gateway_name}{'last_run'} <= time())
			{	
				&log("debug","push new config to $gateway_name");
				my %CONF=%{$SYS{gateways}{$gateway_name}{config}};
		    	$CONF{log}=$LOG;
				$GATEWAYS{$gateway_name}{modul}->set_config(\%CONF);
				$GATEWAYS{$gateway_name}{modul}->read_devices();
				$GATEWAYS{$gateway_name}{'last_run'}=time()+$GATEWAYS{$gateway_name}{'intervall'};
				&log("debug","next run in ".$GATEWAYS{$gateway_name}{'intervall'}." sec");
				if ($sleeptime<($GATEWAYS{$gateway_name}{'intervall'}-1))
				{
					$sleeptime=$GATEWAYS{$gateway_name}{'intervall'}-1;
					if ($sleeptime< 0){$sleeptime=0;}
					&log("debug","set sleeptime to ".$sleeptime." sec");
				}
			}
  	}
  	sleep ($sleeptime);
}

	
SHUTDOWN();


#######################################################
sub daemonize 
#
#	verison:1.0
#	last change:28.03.16
#######################################################
{
	print "switch to daemon mode\n";
	my $pidFile= $SYS{'pidfile'};
	POSIX::setsid or die "setsid: $!";
	my $pid = fork ();
	if ($pid < 0) 
	{
		die "fork: $!";
   	} elsif ($pid) 
   	{
   		open PIDFILE, ">$pidFile" or die "can´t open $pidFile: $!\n";
   		print PIDFILE $pid;
   		close PIDFILE;
		exit (0);
	}
	umask 0;
	foreach (0 .. (POSIX::sysconf (&POSIX::_SC_OPEN_MAX) || 1024))
	{
		POSIX::close $_ 
	}
	open (STDIN, "</dev/null");
	open (STDOUT, ">/dev/null");
	open (STDERR, ">&STDOUT");
}

#######################################################
sub read_configfile
#
#	verison:1.0
#	last change:28.03.16
#######################################################
{
	my $file=shift;
	my $config="";
	
	my $xml=XML::Simple->new();
	
	if ($config = eval {$xml->XMLin($file)}){
		return $config;
	}	
	print "error, cant not read config file:" . $file . ":\n";
	print "usag :$0 --configfile [path and filename] \n";
    exit(0);
}


#################################################
sub su_to_ehcuser
#
# version 1.0
# last modified 23.03.2016
#################################################
{
  my @pw = getpwnam("ehcuser");
  if(@pw) {
    

    # set primary group
    setgid($pw[3]);

    # read all secondary groups into an array:
    my @groups;
    while ( my ($name, $pw, $gid, $members) = getgrent() ) {
      push(@groups, $gid) if ( grep($_ eq $pw[0],split(/\s+/,$members)) );
    }

    # set the secondary groups via $)
    if (@groups) {
      $) = "$pw[3] ".join(" ",@groups);
    } else {
      $) = "$pw[3] $pw[3]";
    }

    setuid($pw[2]);
  }

}
#######################################################
sub log
#	version 3.0
#	change 30.06.2012
#######################################################
{
	my $logdata->{'level'}=lc(shift ||"unkown");
	$logdata->{'msg'}=shift	||"unkown msg";
	($logdata->{'package'},$logdata->{'filename'},$logdata->{'line'}) = caller;
	if ($LOG)
	{   
		$LOG->write($logdata);
	}	
}
#################################################################
sub build_gateways
#	version 3.0
#	change 28.03.2016
#################################################################
{
	&log("info","building gateways");
	
	for my $gateway_name (sort(keys %{$SYS{'gateways'}}))
  	{
  		my %gateway=%{$SYS{'gateways'}{$gateway_name}};
  		&log("info","build connector $gateway_name: ".$gateway{name});
		
		my $modul_path=$SYS{path}."/modul/".$gateway{package}.'/'.$gateway{modul}.".pm";
   		my $modul_name=$gateway{package}.'::'.$gateway{modul};
		
		if (eval { require $modul_path; 1; }) {
        	&log("info","adding server: $gateway_name with modul: ".$modul_name);
        	my %conf=%{$gateway{config}};
        	$conf{log}=$LOG;
        	if (eval {$GATEWAYS{$gateway_name}{modul}=$modul_name->new(%conf);1}){
        		&log("debug","loading ".$gateway{name});
        		$GATEWAYS{$gateway_name}{last_run}=0;
        		if ($gateway{typ} eq "intervall"){
        			$GATEWAYS{$gateway_name}{intervall}=$gateway{time};
        			&log("info","gateway is set to a intervall with ".$gateway{time}." sec");
        		}else{
        			$GATEWAYS{$gateway_name}{intervall}=0;
        			&log("info","gateway is set to a continue");
        		}
        	}else{
        		&log("critical","can not loading ".$gateway_name."::".$gateway{name}." ".$@);
        	}
    	} else {
        	&log("critical","can not adding server: $gateway_name with modul: ".$modul_path);
       		&log("critical","MSG:".$@);
    	}
  	}	
}
#################################################################
sub build_connectors
#	version 3.0
#	change 28.03.2016
#################################################################
{
	&log("info","building connectors");
	
	for my $connector_name (sort(keys %{$SYS{'connectors'}}))
  	{
  		
  		my %connector=%{$SYS{'connectors'}{$connector_name}};
  		if ( ($connector{enable}) ne "true"){
  			&log("info","connector $connector_name: ".$connector{name}." is disable");
			next;
  		}
  		&log("info","build connector $connector_name: ".$connector{name});
		
		my $modul_path=$SYS{path}."/modul/".$connector{package}.'/'.$connector{modul}.".pm";
   		my $modul_name=$connector{package}.'::'.$connector{modul};
		
		if (eval { require $modul_path; 1; }) {
        	&log("info","adding server: $connector_name with modul: ".$modul_name);
        	my %conf;
        	%conf=%{$connector{config}};
        	$conf{log}=$LOG;
        	if (eval {$CONNECTORS{$connector{name}}=$modul_name->new(%conf);1}){
        		&log("debug","loading ".$connector{name});
        		#### push connector to gateways
        		for my $gateway_name (sort(keys %{$connector{'gateways'}}))
        		{
        			if (exists($GATEWAYS{$gateway_name})){
        				&log("info","push ".$connector{name}." to gateway: $gateway_name");
        				$GATEWAYS{$gateway_name}{'modul'}->push_connector($CONNECTORS{$connector{name}});
        			}else{
        				&log("error","can not push ".$connector{'name'}.",gateway $gateway_name not found");
        			}
        		}
        	}else{
        		&log("critical","can not loading ".$connector_name."::".$connector{'name'}." ".$@);
        	}
    	} else {
        	&log("critical","can not adding server: $connector_name with modul: ".$modul_path);
       		&log("critical","MSG:".$@);
    	}
  	}	
}
#################################################################
sub SHUTDOWN 
#	version 3.0
#	change 28.03.2016
#################################################################
{
	&log("emergency","$0 get sig \"$!\" to shutdown ");
	
	exit (0);
}  
1;