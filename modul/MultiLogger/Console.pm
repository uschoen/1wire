#!/usr/bin/perl -w
$| = 1;
package MultiLogger::Console;

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

	
	my $self={};
	bless $self,$class;
	
	$self->init($arg_hash);
	return $self;
}
#######################################################
sub getError
#
#######################################################
{
	my $self=shift;
	return $self->{'errMSG'};
}
#######################################################
sub init
#
#######################################################
{
	my $self= shift;
	my $ARGS_ref= shift;
	my %ARGS=%{$ARGS_ref};
	$self->{'msgformat'}= (exists($ARGS{'msgformat'})) ? $ARGS{'msgformat'} : '';
	$self->{'enabelLog'}= (exists($ARGS{'enabelLog'})) ? $ARGS{'enabelLog'} : 'true';
	
	
	$self->{'errMSG'}="";
	return true;
		
}
#######################################################################
sub message
#######################################################################
{
	my $self=shift;
	my %vars;
	   $vars{'level'}=shift;
	   $vars{'message'}=shift;
	my $message="";
	if ($self->{'enabelLog'} eq 'false'){
		return true;
	}
	if ($self->{'msgformat'}){
		my$sub=$self->{'msgformat'};
		$message=&$sub(%vars);
	}else{
		$message=$vars{'level'}." ".$vars{'message'}."\n";
	}
	print STDOUT $message;
}