package Koha::Plugin::Fi::KohaSuomi::OKMStats::ReportsController;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use C4::Context;
use Try::Tiny;

# my $CONFPATH = dirname($ENV{'KOHA_CONF'});
# my $KOHAPATH = C4::Context->config('intranetdir');

# # Initialize Logger
# my $log_conf = $CONFPATH . "/log4perl.conf";
# Log::Log4perl::init($log_conf);
# my $log = Log::Log4perl->get_logger('reports');

#This gets called from REST api

sub getokmdetails {
    
    my $c = shift->openapi->valid_input or return;

    return try {
        
        my $dbh = C4::Context->dbh();
        my $sth;
        my $okmdata;
        my $ref;

        $sth = $dbh->prepare(
            q{
                SELECT id, individualbranches, startdate, enddate, timestamp from koha_plugin_fi_kohasuomi_okmstats_okm_statistics
            }
         );

        $sth->execute();
        
        # my @array     = $sth->fetchall();
        # my $array_ref = \@array;
        # my $date      = ${$array_ref}[0];
        # $sth->finish;
        
        #my $sql = "SELECT id, individualbranches, startdate, enddate, timestamp from koha_plugin_fi_kohasuomi_okmstats_okm_statistics";

        $ref = $sth->fetchall_arrayref([]);

        #my $array_ref = \@array;
        
        unless ($ref) {
            return $c->render( status  => 404,
                            openapi => { error => "Data not found" } );
        }

        return $c->render( status => 200, openapi => $ref );
    }
    catch {
        $c->unhandled_exception($_);
    }
}

sub getokmreportdata {
    
    my $c = shift->openapi->valid_input or return;

    return try {
        
        
        my $city = Koha::Cities->find( $c->validation->param('city_id') );
        unless ($city) {
            return $c->render( status  => 404,
                            openapi => { error => "City not found" } );
        }

        return $c->render( status => 200, openapi => $city->to_api );
    }
    catch {
        $c->unhandled_exception($_);
    }
}

1;