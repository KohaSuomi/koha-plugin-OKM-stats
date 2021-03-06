#!/usr/bin/perl

use Modern::Perl;
use open qw( :std :encoding(UTF-8) );
binmode( STDOUT, ":encoding(UTF-8)" );

use Getopt::Long;

use Koha::Plugins;
use Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElements;

my $help;
my $limit = '';
my $verbose = 0;
my $forceRebuild;

GetOptions(
    'h|help'             => \$help,
    'l|limit:i'          => \$limit,
    'v|verbose:i'        => \$verbose,
    'f|forceRebuild'     => \$forceRebuild,
);

my $usage = << 'ENDUSAGE';

SYNOPSIS:

This script checks all modified MARCXMLs from biblioitems-table and recalculates
the special data_elements to the koha.biblio_data_elements -table.

These data_elements can be conveniently used for statistical purposes.

USAGE:

From console:
~/\$ perl update_biblio_data_elements.pl --verbose 2

From cronjobs (recommended scheduling):
30 1 * * *      \$KOHA_CRONJOB_TRIGGER cronjobs/update_biblio_data_elements.pl -v 2

This script has the following parameters :

    -h --help         this message

    -l --limit        an SQL LIMIT -clause for testing purposes, defaults to no limit.

    -v --verbose      Level of verbosity desired, defaults to none.
                      Valid values 0, 1 or 2.

    -f --forceRebuild Rebuild data_elements for all biblioitems.

ENDUSAGE

if ($help) {
    print $usage;
    exit;
}

if ($limit) {
    $limit =~ s/;//g; #Evade SQL injection :)
}

Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElements::UpdateBiblioDataElements($forceRebuild, $limit, $verbose);
