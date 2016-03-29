#!/usr/bin/perl -w
$| = 1;
package MultiLogger::Dispatcher;

use strict;
use warnings;
use Data::Dumper;

use MultiLogger::File;
use MultiLogger::Console;
use Time::HiRes qw(gettimeofday);
use constant true => 1;
use constant false => 0;
#######################################################
sub new
#	Vars=%config
#	{'log_object'}=Instants zum loggen
#
#######################################################
{
	my $class=shift;
	my $arg_hash = (ref($_[0]) eq 'HASH') ? $_[0] : {@_};

	
	my $self={};
	bless $self,$class;
	
	$self->init($arg_hash);
	return $self;
}

#######################################################
#
sub init
#
#######################################################

{
	my $self= shift;
	my $ARGS_ref= shift;
	my %ARGS=%{$ARGS_ref};
	
	$self->{'countLogObject'}=0;
	
	if (!($ARGS_ref)){
		print "get no config for logging\n";
		return 0;
	}
	if (!(exists($ARGS{'output'}))){
		print "no output for logging\n";
		return 0;	
	}
	
	
	#my $logger=MultiLogger::Dispatcher->new();
	$ARGS{'msgformat'}=sub {
						my %p = @_;
						(my $seconds, my $microseconds) = gettimeofday;
						my @dta=localtime(time);
						$dta[5]+=1900;
						$dta[4]+=1;
						my $pid=$$;
						my $string=sprintf("%04d.%02d.%02s %02d:%02d:%02d.%06d %-8s %6d %s\n",$dta[5],$dta[4],$dta[3],$dta[2],$dta[1],$dta[0],$microseconds,$p{'level'},$pid,$p{'message'});
						return $string; 
	};
	my %outputs=%{$ARGS{'output'}};
	my $output;
	
	foreach $output ( keys %outputs){
		if (ref($outputs{$output}) eq "ARRAY"){
			### more than fon outouts
			my @outputs2=@{$outputs{$output}};
			foreach my $output2 (@outputs2){
				my $loglevel="";
				my $configOutput=$output2;
				if (!(exists($configOutput->{'loglevel'}))){
					$loglevel=$ARGS{'loglevel'};
				}else{
					$loglevel=$configOutput->{'loglevel'};
				}
				$configOutput->{'msgformat'}=$ARGS{'msgformat'};
				if (exists($configOutput->{'enable'})){
					if ($configOutput->{'enable'} ne "true"){
						next;
					}
				}
				### file
				if ($output eq "file"){
					$self->add(MultiLogger::File->new($configOutput),$loglevel);
					next;
				}
				### console
				if ($output eq "console"){
					$self->add(MultiLogger::Console->new($configOutput),$loglevel);
					next;
				}
				print "error unkown logging typ ($output), please check config\n";
			}
			
		}else{
			### one output
			my $loglevel="";
			my $configOutput=$outputs{$output};
			if (!(exists($configOutput->{'loglevel'}))){
				$loglevel=$ARGS{'loglevel'};
			}else{
				$loglevel=$configOutput->{'loglevel'};
			}
			$configOutput->{'msgformat'}=$ARGS{'msgformat'};
		
			### file
			if ($output eq "file"){
				$self->add(MultiLogger::File->new($configOutput),$loglevel);
				next;
			}
			### console
			if ($output eq "console"){
				$self->add(MultiLogger::Console->new($configOutput),$loglevel);
				next;
			}
			print "error unkown logging typ ($output), please check config\n";
		}
	}	
}

#######################################################
#
sub add
#
#######################################################

{
	my $self= shift;
	my $logobject=shift;
	my $logtyp=shift||{unkown=>1};
		
	if (!($logobject)){
		return false;
	}
	$self->{'countLogObject'}++;
	$self->{'logObject'}{$self->{'countLogObject'}}{'object'}=$logobject;
	$self->{'logObject'}{$self->{'countLogObject'}}{'logtyp'}=$logtyp;
	return true;
}
#######################################################
#
sub write
#
#######################################################

{
	my $self=shift;
	my $Parms=shift||"";
	
	my $defaultsParms->{'level'}="unkown";
	$defaultsParms->{'msg'}="unkown msg";
	$defaultsParms->{'package'} = "unkown";
	$defaultsParms->{'filename'} = "unkown";
	$defaultsParms->{'line'} = "unkown";
	$Parms={%$defaultsParms,%$Parms};
		
	
	my $level=$Parms->{'level'};
	my $message=$Parms->{'package'}." ".$Parms->{'filename'}." ".$Parms->{'line'}."->> ".$Parms->{'msg'};
	
	my $logobject;
	my %logObjects=%{$self->{'logObject'}};
	foreach $logobject ( keys %logObjects){
		my $logtyp=$self->{'logObject'}{$logobject}{'logtyp'};
		if (exists($logtyp->{$level})){
			#### bekannter loglevel
			if ($logtyp->{$level} eq 'true'){
				### loglevel enable
				if (!($self->{'logObject'}{$logobject}{'object'}->message($level,$message))){
						my $errMSG=$self->{'logObject'}{$logobject}{'object'}->getError();
						delete($self->{'logObject'}{$logobject});
						$self->writeMessage("error","delete LOGOBJECT err: ".$errMSG);
				}
			}else{
				### loglevel disable
				next;
			}
		}else{
			#### unbekannter Loglevel
			if (exists($logtyp->{'unkown'})){
				if ($logtyp->{'unkown'} eq 'true'){
					### unbekannte loglevel zulassen
					if (!($self->{'logObject'}{$logobject}{'object'}->message($level,$message))){
						my $errMSG=$self->{'logObject'}{$logobject}{'object'}->getError();
						delete($self->{'logObject'}{$logobject});
						$self->writeMessage("error","delete LOGOBJECT err: ".$errMSG);
					}
				}else{
					### unbekannte loglevel ignorieren
					next;
				}
			}else{
				### unbekannte loglevel ignorieren
				next;
			}
		}
	}
}
1;