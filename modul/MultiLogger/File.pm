#!/usr/bin/perl -w
$| = 1;
package MultiLogger::File;

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
sub init
#	
#
#######################################################
{
	my $self= shift;
	my $ARGS_ref= shift;
	my %ARGS=%{$ARGS_ref};
	$self->{'filename'}= (exists($ARGS{'filename'})) ? $ARGS{'filename'} : 'logfile.log';
	$self->{'clearlog'}= (exists($ARGS{'clearlog'})) ? $ARGS{'clearlog'} : 'true';
	$self->{'dir'}= (exists($ARGS{'dir'})) ? $ARGS{'dir'} : '';
	$self->{'msgformat'}= (exists($ARGS{'msgformat'})) ? $ARGS{'msgformat'} : '';
	$self->{'logrotation'}=(exists($ARGS{'logrotation'})) ? $ARGS{'logrotation'} : 'false';
	$self->{'filesize'}=(exists($ARGS{'filesize'})) ? $ARGS{'filesize'} : '1000000000';
	$self->{'holdzipfiles'}=(exists($ARGS{'holdzipfiles'})) ? $ARGS{'holdzipfiles'} : 0;
	$self->{'enabelLog'}=(exists($ARGS{'enabelLog'})) ? $ARGS{'enabelLog'} : 'true';
	
	$self->{'errMSG'}="";
	$self->createnewFile();
		
}
#######################################################
sub message
#
#######################################################
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
		my $sub=$self->{'msgformat'};
		$message=&$sub(%vars);
	}else{
		$message=$vars{'level'}." ".$vars{'message'}."\n";
	}
	$self->writeMSG($message);
	return true;
}
#######################################################
sub logrotation
#
#######################################################
{
	my $self=shift;
	
	if ($self->{'logrotation'} eq 'false'){
		return false;
	}
	my $filename=$self->{'dir'}.$self->{'filename'};
	my $zipName=$self->{'dir'}.$self->{'filename'}.time().".zip";
	my $size= -s $filename;
	if (!($size)){return false;}
	if ($size < $self->{'filesize'}*1024){
		return false;
	}
	### Testen Filehandel OK
	my $FH=$self->{'filehandel'};
	print $FH "create new logfile (size is $size), zip old file to $zipName\n"; 
	
	if ($FH){
		close($FH);
	}
	use Archive::Zip;
	my $zip = Archive::Zip->new();
	$zip->addFile( $filename );
	$zip->writeToFileNamed($zipName);
	unlink($filename);
	$self->createnewFile();
	return true;
}	
#######################################################
sub writeMSG
#
#######################################################
{
	my $self=shift;
	my $line=shift;
	
	my $FH=$self->{'filehandel'};
	if (!($FH)){
		if (!($self->createFilehandel())){
			return false;
		}
		$FH=$self->{'filehandel'};
	}
	print $FH $line;
	
	$self->logrotation();
	return true;
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
sub createFilehandel
#
#######################################################
{
	my $self=shift;
	my $filename=$self->{'dir'}.$self->{'filename'};
	my $FH;
	if (!(open($FH, ">>$filename")))
	{ 
		$self->{'enabelLog'}=false;
		$self->{'errMSG'}="can not create Logfile";
		$self->{'filehandel'}=false;
		return false;	
	}
	$self->{'filehandel'}=$FH;
	return true;
}
#######################################################
sub createnewFile
#
#######################################################
{
	my $self=shift;
	my $FH;
	my $filename=$self->{'dir'}.$self->{'filename'};
	
	my %vars;
	$vars{'level'}="info";
	my  $message;
	if ($self->{'clearlog'} eq 'true')
	{
		if (open($FH, ">$filename"))
		{ 
			$vars{'message'}="Filelog create new file";
		}else{
			$self->{'enabelLog'}=false;
			$self->{'errMSG'}="can not create Logfile";
			$self->{'filehandel'}=false;
		return false;
		}
	}else{
		if (open($FH, ">>$filename"))
		{
			$vars{'message'}="Filelog append log";
		}else{
			$self->{'enabelLog'}=false;
			$self->{'errMSG'}="can not create Logfile";
			$self->{'filehandel'}=false;
			return false;
		}
	}
	if (!($FH)){
		$self->{'enabelLog'}=false;
		$self->{'errMSG'}="can not create Logfile";
		$self->{'filehandel'}=false;
		return false;	
	}
	if ($self->{'msgformat'}){
		my $sub=$self->{'msgformat'};
		$message=&$sub(%vars);
	}else{
		$message=$vars{'level'}." ".$vars{'message'}."\n";
	}
	print $FH $message;
	$self->{'filehandel'}=$FH;
	return true;
}