Perl script to read onewire sensor data from a rasperry. The script can be run via console or start as damon. A init.d script is included
you cann add connector to send the data to diverents server.
avaible connectors:
-homematic CCU2 via XML API
	you can update Homematic Vars with the temperatur sensor data
-MYSQL Database
	you can insert sensor data in a mysql database for statistic data
	
for installation see /doc/install.txt
for changlog se /doc/CHANGELOG.txt

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
#  Homepage:  http://fhem.de
#
# $Id: EHCGateway.pl  2016-01-01 07:33:35Z ullrich schoen $


