#!/usr/bin/perl -w
$| = 1;

package Connector::Mysql;
use strict;
use warnings;
use Data::Dumper;  
use DBI;

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
	$self->log("info","mysql build complete");
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
	$self->{'config'}{'db_host'}=(exists($ARGS{'db_host'})) ? $ARGS{'db_host'} : '127.0.0.1';
	$self->{'config'}{'db_name'}=(exists($ARGS{'db_name'})) ? $ARGS{'db_name'} : '';
	$self->{'config'}{'db_password'}=(exists($ARGS{'db_password'})) ? $ARGS{'db_password'} : '';
	$self->{'config'}{'db_table'}=(exists($ARGS{'db_table'})) ? $ARGS{'db_table'} : '';
	$self->{'config'}{'db_user'}=(exists($ARGS{'db_user'})) ? $ARGS{'db_user'} : 'root';
	$self->{'config'}{'fields'}=(exists($ARGS{'fields'})) ? $ARGS{'fields'} : '';
	
	$self->log("dump","config :".Dumper($self->{config}));
	$self->{'dbh'}=false;
	$self->log("info","Mysql load config complete");
	
}
####################################################### 
sub connect_to_db
#	
#
#######################################################
{
	my $self=shift;
	my $db='DBI:mysql:'.$self->{'config'}{'db_name'}.';host='.$self->{'config'}{'db_host'};
	if ($self->{'dbh'} = DBI->connect(
										$db,
										$self->{'config'}{'db_user'},
										$self->{'config'}{'db_password'},
	            						{ RaiseError => 0 }))
	{
		$self->log("info","connect to ".$self->{'config'}{'db_host'}." DB Name:".$self->{'config'}{'db_name'}." user:".$self->{'config'}{'db_user'});
		return true;
	}else{
		$self->log("error","can not connect to ".$self->{'config'}{'db_host'}." DB Name:".$self->{'config'}{'db_name'}." user:".$self->{'config'}{'db_user'});
		return false;
	}
	           
}
####################################################### 
sub send_data
#	
#
#######################################################
{
	my $self=shift;
	my $data_ref=shift;
	my %data=%{$data_ref};
	
	if (!($self->{'dbh'}))
	{
		if (!($self->connect_to_db()))
		{
			return false;
		}
	}
	my $fields="";
	my $values="";
	for my $field (sort(keys %{$self->{'config'}{'fields'}}))
  	{
  		if (exists($data{$field}))
  		{
  			if ($fields){
  				$fields=$fields.",";
  			}
  			$fields=$fields."`".$self->{'config'}{'fields'}{$field}."`";
  			if ($values){
  				$values=$values.",";
  			}
  			$values=$values."'".$data{$field}."'";
  			
  		}else{
  			$self->log("error","can not find field:$field. no data send");
  			return false;
  		}
  	}
  	my $sql_string="INSERT INTO `".$self->{'config'}{'db_table'}."` (".$fields.") VALUES (".$values.");";
  	$self->log("debug","sql string: $sql_string");
  	if (my $result=$self->{'dbh'}->do($sql_string))
  	{
  		$self->log("debug","sql request succescful");
  		return true;
	}
  	$self->log("error","error in sql statment");
  	return false;
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