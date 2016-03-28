#!/usr/bin/perl -w 
$| = 1;

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use Data::Dumper;
use XML::Simple;
use POSIX;

our %SYS=();   				# global configuration
our $LOG;    				# loggin instance
my $configFile="";
my $daemon="false";

GetOptions('configfile=s' => \$configFile,
			"daemon=s"   => \$daemon)
or die "Usage: $0 --configfile --daemon true\n";

### loading configuration file
%SYS = %{(&readconfig($configFile))};

### overwirte config with options
if ($daemon){
	$SYS{'daemon'}=$daemon;
} 
### daemonize ?
if ( $SYS{daemon} eq "true" ) {
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
	$SIG{'PIPE'} = \&shutdown;
	$SIG{'INT'}  = \&shutdown;
	$SIG{'TERM'} = \&shutdown;
	$SIG{'HUP'}  = \&shutdown;
	chdir "/";
	umask 0;
	foreach (0 .. (POSIX::sysconf (&POSIX::_SC_OPEN_MAX) || 1024))
	{
		POSIX::close $_ 
	}
	open (STDIN, "</dev/null");
	open (STDOUT, ">/dev/null");
	open (STDERR, ">&STDOUT");
	
}	
	
	

use lib "/usr/local/etc/1WireToHM/modul";




#######################################################
sub readconfig
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
	print "error, cant not read config file " . $file . "\n";
    exit(0);
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
	return 0;	
}
#################################################################
sub shutdown 
#	version 3.0
#	change 28.03.2016
#######################################################
{
	&log("emergency","$0 get sig to shutdown ");
    exit (0);
}  

