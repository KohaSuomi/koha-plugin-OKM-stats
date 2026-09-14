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

my $dbh;

my $module = 'C4::KohaSuomi::Tweaks';
if (try_load($module)) {
  warn "ReportsTool C4::KohaSuomi::Tweaks loaded\n";
  $dbh = C4::KohaSuomi::Tweaks->dbh();
} else {
  warn "ReportsTool C4::KohaSuomi::Tweaks not loaded\n";
  $dbh = C4::Context->dbh();
}

#This gets called from REST api

sub try_load {
  my $mod = shift;

  eval("use $mod");

  if ($@) {
    #print "\$@ = $@\n";
    return(0);
  } else {
    return(1);
  }
}

sub getokmreportlist {

    my $c = shift->openapi->valid_input or return;

    return try {

        my $sth;
        my $okmdata;
        my $ref;

        $sth = $dbh->prepare(
            q{
                SELECT id, individualbranches, DATE_FORMAT(startdate, GET_FORMAT(DATE, 'EUR')), DATE_FORMAT(enddate, GET_FORMAT(DATE, 'EUR')), timestamp from koha_plugin_fi_kohasuomi_okmstats_okm_statistics
            }
         );

        $sth->execute();

        $ref = $sth->fetchall_arrayref([]);

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

        my $sth;
        my $okmdata;
        my $ref;

        my $reportidtoget = $c->validation->param('okm_id');

        $sth = $dbh->prepare(
            q{
                SELECT okm_serialized from koha_plugin_fi_kohasuomi_okmstats_okm_statistics where id = ?
            }
         );

        $sth->execute($reportidtoget);

        $ref = $sth->fetchall_arrayref();

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

1;