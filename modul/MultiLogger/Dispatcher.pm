#!/usr/bin/perl -w
$| = 1;
package MultiLogger::Dispatcher;

use strict;
use warnings;
use Data::Dumper;
use MultiLogger::Dispatcher;
use MultiLogger::File;
use MultiLogger::Console;
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