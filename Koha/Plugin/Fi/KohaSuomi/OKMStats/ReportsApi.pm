package Koha::Plugin::Fi::KohaSuomi::OKMStats::OkmApi;

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
use FindBin qw($Bin);
use lib "$Bin";
use Koha::Exceptions;
use XML::LibXML;
use IO::Socket::INET;
use IO::Socket qw(AF_INET AF_UNIX SOCK_STREAM SHUT_WR);
use Socket qw(:crlf);
use Try::Tiny;
use Mojo::Log;
use File::Basename;
use C4::Context;
use Encode;
use utf8;
use strict;
use warnings qw( all );
use Log::Log4perl;
use Koha::Cities;

my $CONFPATH = dirname($ENV{'KOHA_CONF'});
my $KOHAPATH = C4::Context->config('intranetdir');

# Initialize Logger
my $log_conf = $CONFPATH . "/log4perl.conf";
Log::Log4perl::init($log_conf);
my $log = Log::Log4perl->get_logger('reports');

#This gets called from REST api
sub process {

    my $c = shift->openapi->valid_input or return;

    my $body       = $c->req->body;
    my $request    = $c->param('query') || $body || '';

    $log->info("Request received.");
    
    my $response = "Kissa";

    return try {
        $c->render(status => 200, openapi => $response);
        $log->info("XML response passed to endpoint.");
    } catch {
        Koha::Exceptions::rethrow_exception($_);
    }
}

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $cities_set = Koha::Cities->new;
        my $cities = $c->objects->search( $cities_set );
        return $c->render( status => 200, openapi => $cities );
    }
    catch {
        $c->unhandled_exception($_);
    };

}

sub getokm {
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