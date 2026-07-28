#!/usr/bin/perl

# Copyright 2026 Koha-Suomi Oy
#
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
use open qw( :std :encoding(UTF-8) );
binmode( STDOUT, ":encoding(UTF-8)" );

use Getopt::Long;

use C4::Context;

use Koha::Biblios;
use Koha::Old::Biblios;

use Koha::Plugins;
use Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement;
use Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElements;

my $help;
my $verbose = 0;
my $fix = 0;

GetOptions(
    'h|help'    => \$help,
    'v|verbose' => \$verbose,
    'f|fix'     => \$fix,
);

my $usage = << 'ENDUSAGE';


This script has the following parameters:

    -h --help       this helpfull message
    -v --verbose    more chatty script
    -f --fix        actually fix rows

ENDUSAGE

my $dbh = C4::Context->dbh;

print "Collecting all biblios not marked as deleted but found from deletedbiblio table.\n";

my $missed_deleted = "SELECT biblionumber
FROM koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements
WHERE deleted = 0
AND biblionumber IN(SELECT biblionumber FROM deletedbiblio)";
my $sth = $dbh->prepare($missed_deleted);
$sth->execute();

my @missed_deleted_biblios;
while (my $data = $sth->fetchrow_hashref){
    push  @missed_deleted_biblios, $data;
}

if(@missed_deleted_biblios){
    print "Found ".scalar @missed_deleted_biblios." biblios.\n";
} else {
    print "Nothing found.\n";
}

my $fixed_count = 0;
foreach my $missed_deleted_biblio (@missed_deleted_biblios){
    my $biblionumber = $missed_deleted_biblio->{biblionumber};
    print "Biblio $biblionumber has been deleted but is not marked as deleted.\n" if $verbose;
    if($fix){
        print "Fixing columns 'deleted' and 'deleted_on' for biblio $biblionumber.\n" if $verbose;
        my $bde = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement::DBI_getBiblioDataElement($biblionumber);
        my $timestamp = Koha::Old::Biblios->find($biblionumber)->timestamp;
        $bde->set_deleted(1);
        Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement::dbi_update_single_column($biblionumber, 'deleted', $bde->{deleted});
        $bde->set_deleted_on($timestamp);
        Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement::dbi_update_single_column($biblionumber, 'deleted_on', $bde->{deleted_on});
        $fixed_count++;
    }
}

print "Fixed $fixed_count biblios.\n" if $fixed_count;

print "------\n";
print "Collecting all biblios marked as deleted but no found from biblio table.\n";

my $missed_active = "SELECT biblionumber
FROM koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements
WHERE deleted = 1
AND biblionumber IN(SELECT biblionumber FROM biblio)";
$sth = $dbh->prepare($missed_active);
$sth->execute();

my @missed_active_biblios;
while (my $data = $sth->fetchrow_hashref){
    push  @missed_active_biblios, $data;
}

if(@missed_active_biblios){
    print "Found ".scalar @missed_active_biblios." biblios.\n";
} else {
    print "Nothing found.\n";
}

$fixed_count = 0;

foreach my $missed_active_biblio (@missed_active_biblios){
    my $biblionumber = $missed_active_biblio->{biblionumber};
    print "Biblio $biblionumber has not been deleted but is marked as deleted.\n" if $verbose;
    if($fix){
        print "Fixing columns 'deleted' and 'deleted_on' for biblio $biblionumber.\n" if $verbose;
        my $bde = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement::DBI_getBiblioDataElement($biblionumber);
        $bde->set_deleted(0);
        Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement::dbi_update_single_column($biblionumber, 'deleted', $bde->{deleted});
        $bde->set_deleted_on(undef);
        Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement::dbi_update_single_column($biblionumber, 'deleted_on', $bde->{deleted_on});
        $fixed_count++;
    }
}

print "Fixed $fixed_count biblios.\n" if $fixed_count;