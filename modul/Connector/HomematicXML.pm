#!/usr/bin/perl -w
$| = 1;

package Connector::HomematicXML;
use strict;
use warnings;
use Data::Dumper;  
use LWP::Simple;
use XML::Simple;

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
	$self->{'config'}{'fields'}=(exists($ARGS{'fields'})) ? $ARGS{'fields'} : {};
	$self->{'config'}{'hm_url'}=(exists($ARGS{'hm_url'})) ? $ARGS{'hm_url'} : 'http://127.0.0.1/config/xmlapi/statechange.cgi';
	
	$self->log("dump","config data".Dumper($self->{'config'}));
	$self->log("info","HomematicXML load config complete");
	
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
	
	$self->log("dump","send data:". Dumper (%data));
	
	my $url_values="";
	for my $field (sort(keys %{$self->{'config'}{'fields'}}))
  	{
  		if (exists($data{$field}))
  		{
  			if ($url_values){
  				$url_values=$url_values."&";
  			}
  			$url_values=$url_values.$self->{'config'}{'fields'}{$field}."=".$data{$field};
  		}else{
  			$self->log("error","can not find field:$field. no data send");
  			return false;
  		}
  	}
 
	my $url=  $self->{'config'}{'hm_url'}."?".$url_values;
	$self->log("debug","send:".$url);
	my $content = get($url);
	$self->log("dump","answer:".$content);
	return $self->send_data_succes($content);
}
####################################################### 
sub send_data_succes
#	
#
#######################################################
{
	my $self=shift;
	my $xmlanswer=shift;
	my $config;
	
	my $xml=XML::Simple->new();
	
	if ($config = eval {$xml->XMLin($xmlanswer)}){
		my %msg;
		%msg=%{$config};
		if ($msg{'not_found'}){
			$self->log("error","ise id not found in homematic");
   			return false;
		}
		if ($msg{'changed'}){
			$self->log("debug","request was successful");
   			return true;
		}
		$self->log("info","unkown answer from HM");
   		return true;	
	}else{
		$self->log("error","can not read xml answer from HM:");
   		&log("critical","MSG:".$@);
	}
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