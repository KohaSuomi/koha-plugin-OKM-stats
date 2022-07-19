#!/usr/bin/perl

# Copyright KohaSuomi
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

use C4::Context();

use Koha::Plugins;
use Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM;
use Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKMGroupStatistics;

my $help;
my $verbose;

GetOptions(
    'h|help'           => \$help,
    'v|verbose'        => \$verbose,
);
my $usage = << 'ENDUSAGE';

This script converts statistics from okm_statistics table into JSON format
and inserts them into the koha_plugin_fi_kohasuomi_okmstats_okm_statistics
table.

This script has the following parameters :

    -h --help       this message
    -v --verbose    More chatty script.

EXAMPLES:

    ./convert_old_statistics.pl -v

ENDUSAGE

if ($help) {
    print $usage;
    exit;
}

my $dbh = C4::Context->dbh;

# Collect all old statistics
my $query = "SELECT * FROM okm_statistics";
my $sth = $dbh->prepare($query);
$sth->execute();

my @statistics;
while (my $data = $sth->fetchrow_hashref){
    push @statistics, $data;
}

foreach my $statistic (@statistics){

    my $timeperiod = join ("-", $statistic->{startdate}, $statistic->{enddate});
    my $individual_branches = $statistic->{individualbranches};
    my $okm = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM->new( undef, $timeperiod, undef, $individual_branches, $verbose );
    my $new_okm_statistics = $okm->{lib_groups};

    my $okm_serialized = $statistic->{okm_serialized};
    my $okm_deserialized = _deserialize($okm_serialized);
    my $old_okm_statistics = $okm_deserialized->{lib_groups};

    while(my ($key, $value) = each %$old_okm_statistics){
        my $branch = $value->{branchCategory};

        $new_okm_statistics->{$branch}->{statistics}->{collection_by_homebranch}->{total} = $value->{statistics}->{collection};
        $new_okm_statistics->{$branch}->{statistics}->{collection_by_homebranch}->{books_total} = $value->{statistics}->{collectionBooksTotal};
        $new_okm_statistics->{$branch}->{statistics}->{collection_by_homebranch}->{books_finnish} = $value->{statistics}->{collectionBooksFinnish};
        $new_okm_statistics->{$branch}->{statistics}->{collection_by_homebranch}->{books_swedish} = $value->{statistics}->{collectionBooksSwedish};
        $new_okm_statistics->{$branch}->{statistics}->{collection_by_homebranch}->{books_other_lang} = $value->{statistics}->{collectionBooksOtherLanguage};
        $new_okm_statistics->{$branch}->{statistics}->{collection_by_homebranch}->{books_fiction_adult} = $value->{statistics}->{collectionBooksFictionAdult};
        $new_okm_statistics->{$branch}->{statistics}->{collection_by_homebranch}->{books_fiction_juvenile} = $value->{statistics}->{collectionBooksFictionJuvenile} ;
        $new_okm_statistics->{$branch}->{statistics}->{collection_by_homebranch}->{books_fact_adult} = $value->{statistics}->{collectionBooksNonFictionAdult};
        $new_okm_statistics->{$branch}->{statistics}->{collection_by_homebranch}->{books_fact_juvenile} = $value->{statistics}->{collectionBooksNonFictionJuvenile};
        $new_okm_statistics->{$branch}->{statistics}->{collection_by_homebranch}->{sheet_music_score} = $value->{statistics}->{collectionSheetMusicAndScores};
        $new_okm_statistics->{$branch}->{statistics}->{collection_by_homebranch}->{musical_recordings} = $value->{statistics}->{collectionMusicalRecordings};
        $new_okm_statistics->{$branch}->{statistics}->{collection_by_homebranch}->{other_recordings} = $value->{statistics}->{collectionOtherRecordings};

        my $collectionVideos = $value->{statistics}->{collectionVideos};
        my $collectionDVDsAndBluRays = $value->{statistics}->{collectionDVDsAndBluRays} || 0;
        $new_okm_statistics->{$branch}->{statistics}->{collection_by_homebranch}->{videos} = $collectionVideos + $collectionDVDsAndBluRays;

        $new_okm_statistics->{$branch}->{statistics}->{collection_by_homebranch}->{celia} = $value->{statistics}->{collectionCelia};

        my $collectionCDROMs = $value->{statistics}->{collectionCDROMs} || 0;
        my $collectionOther = $value->{statistics}->{collectionOther};
        $new_okm_statistics->{$branch}->{statistics}->{collection_by_homebranch}->{other} = $collectionOther + $collectionCDROMs;

        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{total} = $value->{statistics}->{acquisitions};
        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{books_total} = $value->{statistics}->{acquisitionsBooksTotal};
        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{books_finnish} = $value->{statistics}->{acquisitionsBooksFinnish};
        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{books_swedish} = $value->{statistics}->{acquisitionsBooksSwedish};
        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{books_other_lang} = $value->{statistics}->{acquisitionsBooksOtherLanguage};
        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{books_fiction_adult} = $value->{statistics}->{acquisitionsBooksFictionAdult};
        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{books_fiction_juvenile} = $value->{statistics}->{acquisitionsBooksFictionJuvenile};
        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{books_fact_adult} = $value->{statistics}->{acquisitionsBooksNonFictionAdult};
        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{books_fact_juvenile} = $value->{statistics}->{acquisitionsBooksNonFictionJuvenile};
        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{sheet_music_score} = $value->{statistics}->{acquisitionsSheetMusicAndScores};
        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{musical_recordings} = $value->{statistics}->{acquisitionsMusicalRecordings};
        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{other_recordings} = $value->{statistics}->{acquisitionsOtherRecordings};

        my $acquisitionsVideos = $value->{statistics}->{acquisitionsVideos};
        my $acquisitionsDVDsAndBluRays = $value->{statistics}->{acquisitionsDVDsAndBluRays} || 0;
        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{videos} = $acquisitionsVideos + $acquisitionsDVDsAndBluRays;

        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{celia} = $value->{statistics}->{acquisitionsCelia};

        my $acquisitionsCDROMs = $value->{statistics}->{acquisitionsCDROMs} || 0;
        my $acquisitionsOther = $value->{statistics}->{acquisitionsOther};
        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{other} = $acquisitionsOther + $acquisitionsCDROMs;

        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{expenditures} = $value->{statistics}->{expenditureAcquisitions};
        $new_okm_statistics->{$branch}->{statistics}->{acquisitions}->{expenditures_books} = $value->{statistics}->{expenditureAcquisitionsBooks};

        $new_okm_statistics->{$branch}->{statistics}->{issues}->{total} = $value->{statistics}->{issues};
        $new_okm_statistics->{$branch}->{statistics}->{issues}->{books_total} = $value->{statistics}->{issuesBooksTotal};
        $new_okm_statistics->{$branch}->{statistics}->{issues}->{books_finnish} = $value->{statistics}->{issuesBooksFinnish};
        $new_okm_statistics->{$branch}->{statistics}->{issues}->{books_swedish} = $value->{statistics}->{issuesBooksSwedish};
        $new_okm_statistics->{$branch}->{statistics}->{issues}->{books_other_lang} = $value->{statistics}->{issuesBooksOtherLanguage};
        $new_okm_statistics->{$branch}->{statistics}->{issues}->{books_fiction_adult} = $value->{statistics}->{issuesBooksFictionAdult};
        $new_okm_statistics->{$branch}->{statistics}->{issues}->{books_fiction_juvenile} = $value->{statistics}->{issuesBooksFictionJuvenile};
        $new_okm_statistics->{$branch}->{statistics}->{issues}->{books_fact_adult} = $value->{statistics}->{issuesBooksNonFictionAdult};
        $new_okm_statistics->{$branch}->{statistics}->{issues}->{books_fact_juvenile} = $value->{statistics}->{issuesBooksNonFictionJuvenile};
        $new_okm_statistics->{$branch}->{statistics}->{issues}->{sheet_music_score} = $value->{statistics}->{issuesSheetMusicAndScores};
        $new_okm_statistics->{$branch}->{statistics}->{issues}->{musical_recordings} = $value->{statistics}->{issuesMusicalRecordings};
        $new_okm_statistics->{$branch}->{statistics}->{issues}->{other_recordings} = $value->{statistics}->{issuesOtherRecordings};

        my $issuesVideos = $value->{statistics}->{issuesVideos};
        my $issuesDVDsAndBluRays = $value->{statistics}->{issuesDVDsAndBluRays} || 0;
        $new_okm_statistics->{$branch}->{statistics}->{issues}->{videos} = $issuesVideos + $issuesDVDsAndBluRays;

        $new_okm_statistics->{$branch}->{statistics}->{issues}->{celia} = $value->{statistics}->{issuesCelia};

        my $issuesCDROMs = $value->{statistics}->{issuesCDROMs} || 0;
        my $issuesOther = $value->{statistics}->{issuesOther};
        $new_okm_statistics->{$branch}->{statistics}->{issues}->{other} = $issuesOther + $issuesCDROMs;

        $new_okm_statistics->{$branch}->{statistics}->{deleted}->{total} = $value->{statistics}->{discards};
        $new_okm_statistics->{$branch}->{statistics}->{active_borrowers} = $value->{statistics}->{activeBorrowers};

    }

    $okm->{lib_groups} = $new_okm_statistics;
    $okm->save();
}

sub _deserialize {
    my $serialized = shift;
    my $VAR1;
    eval $serialized if $serialized;

    #Rebuild some cumbersome objects
    if ($VAR1) {
        my ($startDate, $endDate) = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM::StandardizeTimeperiodParameter($VAR1->{startDateISO}.'-'.$VAR1->{endDateISO});
        $VAR1->{startDate} = $startDate;
        $VAR1->{endDate} = $endDate;
        return $VAR1;
    }

    return undef;
}
