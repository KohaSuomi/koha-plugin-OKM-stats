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

sub getremovetooldata {
    
    my $c = shift->openapi->valid_input or return;

    return try {
        
        my $dbh = C4::Context->dbh();
        my $sth;
        my $okmdata;
        my $ref;

        $sth = $dbh->prepare(
            q{
                SELECT CONCAT( '<a href=\"/cgi-bin/koha/catalogue/detail.pl?biblionumber=', biblio.biblionumber,'\">', 
       items.barcode, '</a>' ) AS 'Viivakoodi',
       items.cn_sort AS 'Signum',
       items.itemcallnumber AS 'Luokka',
       biblio.author AS 'Tekijä',
       biblio.title AS 'Nimeke',
       biblio.copyrightdate AS 'Julkaisuvuosi/julkaistu alkaen',
       items.dateaccessioned AS 'Vastaanotettu',
       items.itype AS 'Nidetyyppi', 
        bda.itemtype AS 'Aineistotyyppi',
       items.issues AS 'Lainat',
       items.renewals AS 'Uusinnat',
       (IFNULL(items.issues, 0)+IFNULL(items.renewals, 0)) AS 'Lainat ja uusinnat yhteensä', 
       items.datelastborrowed AS 'Viimeksi lainattu',
       items.datelastseen AS 'Viimeksi havaittu',
       items.onloan AS 'Eräpäivä',
       bda.primary_language AS 'Kieli'      

FROM items
LEFT JOIN biblioitems ON (items.biblioitemnumber=biblioitems.biblioitemnumber) 
LEFT JOIN biblio ON (biblioitems.biblionumber=biblio.biblionumber)
LEFT JOIN biblio_data_elements bda ON (biblioitems.biblioitemnumber=bda.biblioitemnumber)

WHERE items.holdingbranch = 'JOE_PYH'
LIMIT 100

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
        
        my $dbh = C4::Context->dbh();
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
        
        # my @array     = $sth->fetchall();
        # my $array_ref = \@array;
        # my $date      = ${$array_ref}[0];
        # $sth->finish;
        
        #my $sql = "SELECT id, individualbranches, startdate, enddate, timestamp from koha_plugin_fi_kohasuomi_okmstats_okm_statistics";

        $ref = $sth->fetchall_arrayref();

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

sub getlainat {
    
   my $c = shift->openapi->valid_input or return;

    return try {
        
        my $dbh = C4::Context->dbh();
        my $sth;
        my $okmdata;
        my $ref;
        
        my $branch = $c->validation->param('branch');
        my $lowdate = $c->validation->param('lowdate');
        my $maxdate = $c->validation->param('maxdate');

        $sth = $dbh->prepare(
            q{
                SELECT b.branchname, i.permanent_location, av.lib, i.itype, bde.itemtype, bde.primary_language, IF(bde.fiction>0, "Fiktio", "Fakta"), count(*)
                FROM statistics s
                    LEFT JOIN items i ON i.itemnumber = s.itemnumber
                    LEFT JOIN branches b ON b.branchcode = i.homebranch
                    LEFT JOIN authorised_values av ON i.permanent_location = av.authorised_value
                    LEFT JOIN biblio_data_elements bde ON i.biblioitemnumber = bde.biblioitemnumber
                
                WHERE b.branchcode = ?
                AND DATE(s.datetime) BETWEEN ? AND ?
                AND s.type = 'issue'
                AND av.category = 'LOC'
                GROUP BY i.homebranch, i.permanent_location, i.itype, bde.itemtype, bde.primary_language, bde.fiction
            }
         );

        $sth->execute($branch, $lowdate, $maxdate);
        
        # my @array     = $sth->fetchall();
        # my $array_ref = \@array;
        # my $date      = ${$array_ref}[0];
        # $sth->finish;
        
        #my $sql = "SELECT id, individualbranches, startdate, enddate, timestamp from koha_plugin_fi_kohasuomi_okmstats_okm_statistics";

        $ref = $sth->fetchall_arrayref();

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

1;