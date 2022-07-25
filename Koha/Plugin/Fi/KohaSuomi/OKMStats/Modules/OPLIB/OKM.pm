package Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM;

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
#use open qw( :std :encoding(UTF-8) );
#binmode( STDOUT, ":encoding(UTF-8)" );
use Carp;

use Data::Dumper;
use URI::Escape;
use File::Temp;
use File::Basename qw( dirname );
use YAML::XS;
use JSON;

use DateTime;

use C4::Items;
use C4::Context;
use C4::Templates qw(gettemplate);

use Koha::Plugin::Fi::KohaSuomi::OKMStats;
use Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElements;
use Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKMLibraryGroup;
use Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKMLogs;

use Koha::ItemTypes;
use Koha::AuthorisedValues;
use Koha::DateUtils qw(dt_from_string);

=head new

    my $okm = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM->new($log, $timeperiod, $limit, $individualBranches, $verbose);
    $okm->createStatistics();

@PARAM1 ARRAYRef of Strings, OPTIONAL, all notifications are collected here in addition to being printed to STDOUT.
                OKM creates an internal Array to store log entries, but you can reuse on big log for multiple OKMs by giving it to them explicitly.
@PARAM4 String, a .csv-row with each element as a branchcode
                'JOE_JOE,JOE_RAN,[...]'
                or
                '_A' which means ALL BRANCHES. Then the function fetches all the branchcodes from DB.

=cut

use Koha::Libraries;
use Koha::Library::Groups;

sub new {
    my ($class, $log, $timeperiod, $limit, $individualBranches, $verbose) = @_;

    my $self = {};
    bless($self, $class);

    $self->{verbose} = $verbose if $verbose;
    $self->{logs} = $log || [];
    $self->loadConfiguration();

    if ($self->{conf}->{blockStatisticsGeneration}) {
        die __PACKAGE__.":> Execution prevented by the System preference 'OKM's 'blockStatisticsGeneration'-flag.";
    }

    my $libraryGroups = $self->setLibraryGroups(  $self->getBranchCategoriesAndBranches($individualBranches)  );
    $self->{individualBranches} = $individualBranches if $individualBranches;

    my ($startDate, $endDate) = StandardizeTimeperiodParameter($timeperiod);
    $self->{startDate} = $startDate;
    $self->{startDateISO} = $startDate->iso8601();
    $self->{endDate} = $endDate;
    $self->{endDateISO} = $endDate->iso8601();
    $self->{limit} = $limit; #Set the SQL LIMIT. Used in testing to generate statistics faster.

    return $self;
}

sub createStatistics {
    my ($self) = @_;

    my $libraryGroups = $self->getLibraryGroups();
    my $notforloan = $self->{conf}->{notForLoanStatuses};
    my $patronCategories = $self->{conf}->{patronCategories};
    my $excluded_itemtypes = $self->{conf}->{excludedItemtypes};

    foreach my $groupcode (sort keys %$libraryGroups) {
        my $libraryGroup = $libraryGroups->{$groupcode};
        my @branches = keys %{$libraryGroup->{branches}};

        print '    #'.DateTime->now()->iso8601()."# Starting $groupcode #\n" if $self->{verbose};
        my $stats = $libraryGroup->getStatistics();

        my $items = $self->fetchItems($notforloan, $excluded_itemtypes, @branches);
        foreach my $itemnumber (sort {$a <=> $b} keys %$items) {
            if( grep $_ eq $items->{$itemnumber}->{homebranch}, @branches ){
                $self->_processItemsDataRow( $stats->{collection_by_homebranch}, $items->{$itemnumber});
            }
            if ( grep $_ eq $items->{$itemnumber}->{holdingbranch}, @branches ){
                $self->_processItemsDataRow( $stats->{collection_by_holdingbranch}, $items->{$itemnumber});
            }
        }

        my $deletedItems = $self->fetchDeletedItems($notforloan, $excluded_itemtypes, @branches);
        foreach my $itemnumber (sort {$a <=> $b} keys %$deletedItems) {
            $self->_processItemsDataRow( $stats->{deleted}, $deletedItems->{$itemnumber} );
        }

        my $acquiredItems = $self->fetchAcquisitions($notforloan, $excluded_itemtypes, @branches);
        foreach my $itemnumber (sort {$a <=> $b} keys %$acquiredItems) {
            $self->_processItemsDataRow( $stats->{acquisitions}, $acquiredItems->{$itemnumber});
        }

        my $issues = $self->fetchIssues($patronCategories, @branches);
        foreach my $itemnumber (sort {$a <=> $b} keys %$issues) {
            foreach my $datetime (keys %{$issues->{$itemnumber}} ){
                $self->_processItemsDataRow( $stats->{issues}, $issues->{$itemnumber}->{$datetime} );
                $self->_processBorrowers( $stats->{active_borrowers}, $issues->{$itemnumber}->{$datetime}->{hashed_borrowernumber} );
            }
        }
    }
}

sub fetchItems {
    my ($self, $notforloan, $excluded_itemtypes, @branches) = @_;
    my @cc = caller(0);
    print '    #'.DateTime->now()->iso8601()."# Starting ".$cc[3]." #\n" if $self->{verbose};
    my $dbh = C4::Context->dbh();
    my $query = "SELECT i.itemnumber, i.biblionumber, i.location, i.cn_sort, i.homebranch,
        i.holdingbranch, bde.itemtype, bde.primary_language, bde.fiction, bde.musical, bde.celia
        FROM items i
        LEFT JOIN koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements bde ON(i.biblioitemnumber = bde.biblioitemnumber)
        WHERE (i.homebranch IN (" . join(',', map {"'$_'"} @branches).")
        OR i.holdingbranch IN (" . join(',', map {"'$_'"} @branches)."))
        AND i.notforloan NOT IN (" . join(',', map {"'$_'"} @$notforloan).")
        AND bde.itemtype NOT IN (" . join(',', map {"'$_'"} @$excluded_itemtypes).")
        AND i.dateaccessioned < ?
        GROUP BY itemnumber";
    if ($self->{limit}) {
        $query .= ' LIMIT '.$self->{limit};
    }
    my $sth = $dbh->prepare($query);
    $sth->execute($self->{endDate});
    if ($sth->err) {
        my @cc = caller(0);
        die $cc[3]."():> ".$sth->errstr;
    }

    my $items = $sth->fetchall_hashref('itemnumber');
    return $items;
}

sub fetchDeletedItems {
    my ($self, $notforloan, $excluded_itemtypes, @branches) = @_;
    my @cc = caller(0);
    print '    #'.DateTime->now()->iso8601()."# Starting ".$cc[3]." #\n" if $self->{verbose};
    my $dbh = C4::Context->dbh();
    my $query = "SELECT di.itemnumber, di.biblionumber, di.location, di.cn_sort, di.homebranch,
        di.holdingbranch, bde.itemtype, bde.primary_language, bde.fiction, bde.musical, bde.celia
        FROM deleteditems di
        LEFT JOIN koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements bde ON(bde.biblioitemnumber = di.biblioitemnumber)
        WHERE di.timestamp > ? AND di.timestamp < ?
        AND bde.itemtype NOT IN (" . join(',', map {"'$_'"} @$excluded_itemtypes).")
        AND di.notforloan not in (" . join(',', map {"'$_'"} @$notforloan).")
        AND di.homebranch in (" . join(',', map {"'$_'"} @branches).")
        GROUP BY itemnumber";
    if ($self->{limit}) {
        $query .= ' LIMIT '.$self->{limit};
    }
    my $sth = $dbh->prepare($query);
    $sth->execute($self->{startDateISO}, $self->{endDateISO});
    if ($sth->err) {
        my @cc = caller(0);
        die $cc[3]."():> ".$sth->errstr;
    }

    my $deletedItem = $sth->fetchall_hashref('itemnumber');
    return $deletedItem;
}

sub fetchAcquisitions {
    my ($self, $notforloan, $excluded_itemtypes, @branches) = @_;
    my @cc = caller(0);
    print '    #'.DateTime->now()->iso8601()."# Starting ".$cc[3]." #\n" if $self->{verbose};
    my $dbh = C4::Context->dbh();
    my $query = "select i.itemnumber, i.biblionumber, i.location, i.cn_sort, i.homebranch,
        i.holdingbranch, i.price, bde.itemtype, bde.primary_language, bde.fiction, bde.musical, bde.celia
        FROM items i
        LEFT JOIN koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements bde ON(i.biblioitemnumber = bde.biblioitemnumber)
        WHERE dateaccessioned >= ? AND dateaccessioned <= ?
        AND bde.itemtype NOT IN (" . join(',', map {"'$_'"} @$excluded_itemtypes).")
        AND i.notforloan not in (" . join(',', map {"'$_'"} @$notforloan).")
        AND i.homebranch in (" . join(',', map {"'$_'"} @branches).")
        GROUP BY itemnumber";
    if ($self->{limit}) {
        $query .= ' LIMIT '.$self->{limit};
    }
    my $sth = $dbh->prepare($query);
    $sth->execute($self->{startDate}, $self->{endDate});
    if ($sth->err) {
        my @cc = caller(0);
        die $cc[3]."():> ".$sth->errstr;
    }

    my $acquiredItems = $sth->fetchall_hashref('itemnumber');
    return $acquiredItems;
}

#Keep this around until we decide about using pseudonymized_transactions
sub fetchIssues {
    my ($self, $patronCategories, @branches) = @_;
    my @cc = caller(0);
    print '    #'.DateTime->now()->iso8601()."# Starting ".$cc[3]." #\n" if $self->{verbose};
    my $dbh = C4::Context->dbh();
    my $query = "(
            SELECT s.branch, s.datetime, s.itemnumber, bde.itemtype, bde.biblioitemnumber,
            bde.primary_language, bde.fiction, bde.musical, bde.celia, i.itemnumber, i.biblionumber,
            i.location, i.cn_sort, i.homebranch
            FROM statistics s
            LEFT JOIN items i ON(s.itemnumber = i.itemnumber)
            LEFT JOIN koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements bde ON(i.biblioitemnumber = bde.biblioitemnumber)
            LEFT JOIN borrowers b ON(s.borrowernumber = b.borrowernumber)
            WHERE s.datetime >= ? AND s.datetime <= ?
            AND (s.type='issue' or s.type='renew')
            AND s.branch IN(" . join(",", map {"'$_'"} @branches).")
            AND b.categorycode IN(" . join(",", map {"'$_'"} @{$patronCategories}).")
        ) UNION (
            SELECT s.branch, s.datetime, s.itemnumber, bde.itemtype, bde.biblioitemnumber,
            bde.primary_language, bde.fiction, bde.musical, bde.celia, di.itemnumber, di.biblionumber,
            di.location, di.cn_sort, di.homebranch
            FROM statistics s
            LEFT JOIN items di ON(s.itemnumber = di.itemnumber)
            LEFT JOIN koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements bde ON(di.biblioitemnumber = bde.biblioitemnumber)
            LEFT JOIN borrowers b ON(s.borrowernumber = b.borrowernumber)
            WHERE s.datetime >= ? AND s.datetime <= ?
            AND (s.type='issue' or s.type='renew')
            AND s.branch IN(" . join(",", map {"'$_'"} @branches).")
            AND b.categorycode IN(" . join(",", map {"'$_'"} @{$patronCategories}).")
        )";
    if ($self->{limit}) {
        $query .= ' LIMIT '.$self->{limit};
    }
    my $sth = $dbh->prepare($query);
    $sth->execute($self->{startDate}, $self->{endDate}, $self->{startDate}, $self->{endDate});
    if ($sth->err) {
        my @cc = caller(0);
        die $cc[3]."():> ".$sth->errstr;
    }
    #since any table used here has no unique value to use as hash key
    #we need to use itemnumber and datetime to take all issues into account
    my $issues = $sth->fetchall_hashref([ qw( itemnumber datetime ) ]);
    return $issues;
}

#USE if we use pseudonymized_transactions (rename this as fetchIssues and delete function above)
sub fetchIssues_newway {
    my ($self, $patronCategories, @branches) = @_;
    my @cc = caller(0);
    print '    #'.DateTime->now()->iso8601()."# Starting ".$cc[3]." #\n" if $self->{verbose};
    my $dbh = C4::Context->dbh();
    my $query = "SELECT id, branchcode, holdingbranch, homebranch, categorycode, location, itemnumber,
        datetime, itemtype, hashed_borrowernumber, transaction_type
        FROM pseudonymized_transactions
        WHERE ( transaction_type = 'issue' OR transaction_type = 'renew' )
        AND categorycode in (" . join(",", map {"'$_'"} @{$patronCategories}).")
        AND holdingbranch in (" . join(',', map {"'$_'"} @branches).")
        AND datetime >= ?
        AND datetime <= ?";
    if ($self->{limit}) {
        $query .= ' LIMIT '.$self->{limit};
    }
    my $sth = $dbh->prepare($query);
    $sth->execute($self->{startDate}, $self->{endDate});
    if ($sth->err) {
        my @cc = caller(0);
        die $cc[3]."():> ".$sth->errstr;
    }

    my $issues = $sth->fetchall_hashref('id');
    return $issues;
}

=head _processBorrowers

    _processBorrowers( $row );

=cut

sub _processBorrowers {
    my ($self, $active_borrowers, $borrowernumber) = @_;
    my %seen;
    if($borrowernumber){
        next if $seen{ $borrowernumber }++;
        $active_borrowers++;
    }
}

=head _processItemsDataRow

    _processItemsDataRow( $row );

=cut

sub _processItemsDataRow {
    my ($self, $stats, $row) = @_;
    my $itemtype = $row->{itemtype};
    my $statCat = $self->{conf}->{itemTypeToStatisticalCategory}->{$itemtype} if $itemtype;
    unless ($statCat) {
        $statCat = 'Other';
    }
    return undef if $statCat eq 'Electronic';

    my $primaryLanguage = $row->{primary_language};
    my $isChildrensMaterial = $self->isItemChildrens($row);
    my $isItemFiction = $self->isItemFiction($row->{cn_sort});
    my $isItemMusical = $self->isItemMusical($row->{cn_sort});
    my $isCelia = $row->{celia};

    $stats->{total}++;
    $stats->{expenditure_acquisitions} += $row->{price} if $row->{price};

    if ($statCat eq "Books") {
        $stats->{books_total}++;
        $stats->{expenditure_acquisitions_books} += $row->{price} if $row->{price};

        if (not(defined($primaryLanguage)) || $primaryLanguage eq 'fin') {
            $stats->{books_finnish}++;
        } elsif ($primaryLanguage eq 'swe') {
            $stats->{books_swedish}++;
        } elsif ($primaryLanguage eq 'sme') {
            $stats->{books_sami}++;
        } else {
            $stats->{books_other_lang}++;
        }

        if ($isItemFiction) {
            if ($isChildrensMaterial) {
                $stats->{books_fiction_juvenile}++;
            } else { #Adults fiction
                $stats->{books_fiction_adult}++;
            }
        } else { #Non-Fiction
            if ($isChildrensMaterial) {
                $stats->{books_fact_juvenile}++;
            } else { #Adults Non-fiction
                $stats->{books_fact_adult}++;
            }
        }
    } elsif ($statCat eq 'Recordings') {
        if ($isCelia) {
            $stats->{celia}++;
        }
        elsif ($isItemMusical) {
            $stats->{musical_recordings}++;
        } else {
            $stats->{other_recordings}++;
        }
    } elsif ( $statCat eq 'Other') {
        $stats->{other}++;
    } elsif ($statCat eq 'Videos') {
        $stats->{videos}++;
    } elsif ($statCat eq 'Celia') {
        $stats->{celia}++;
    }

    $stats->{itemtypes}->{$itemtype}++ if $itemtype;

    if($row->{price}){
        $stats->{expenditures} += sprintf("%.1f", $row->{price});
        if($statCat eq "Books"){
            $stats->{expenditures_books} += sprintf("%.1f", $row->{price});
        }
    }
}

sub getLibraryGroups {
    my $self = shift;

    return $self->{lib_groups};
}

=head setLibraryGroups

    setLibraryGroups( $libraryGroups );

=cut

sub setLibraryGroups {
    my ($self, $libraryGroups) = @_;

    croak '$libraryGroups parameter is not a HASH of groups of branchcodes!' unless (ref $libraryGroups eq 'HASH');
    $self->{lib_groups} = $libraryGroups;

    foreach my $groupname (sort keys %$libraryGroups) {
        $libraryGroups->{$groupname} = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKMLibraryGroup->new(  $groupname, $libraryGroups->{$groupname}->{branches});
    }
    return $self->{lib_groups};
}

=head getBranchCategoriesAndBranches

    Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM::getBranchCategoriesAndBranches();
    $okm->getBranchCategoriesAndBranches();

Calls getOKMBranchCategories() to find the branchCategories and then finds which branchcodes are mapped to those categories.

@RETURNS a hash of branchcategories.categorycode -> branches.branchcode = 1
=cut

sub getBranchCategoriesAndBranches {
    my ($self, $individualBranches) = @_;

    my $libraryGroups;

    if($individualBranches){
        my @iBranchcodes;

        if ($individualBranches eq '_A') {
            my @branchcodes = Koha::Libraries->search();
            foreach my $branchcode (@branchcodes){
                push @iBranchcodes, $branchcode->branchcode;
            }
        }
        else {
            @iBranchcodes = split(',',$individualBranches);
            for(my $i=0 ; $i<@iBranchcodes ; $i++) {
                my $bc = $iBranchcodes[$i];
                $bc =~ s/\s//g; #Trim all whitespace
                $iBranchcodes[$i] = $bc;
            }
        }

        $libraryGroups = {};
        foreach my $branchcode (@iBranchcodes) {
            $libraryGroups->{$branchcode}->{branches} = {$branchcode => 1};
        }
    } else {

        $libraryGroups = $self->getOKMBranchCategories();

        foreach my $categoryCode (keys %{$libraryGroups}) {
            my @branchcodes =  Koha::Library::Groups->find({title => $categoryCode})->libraries if $categoryCode;
            if (not(@branchcodes) || scalar(@branchcodes) <= 0) {
                $self->log("Statistical library group $categoryCode has no libraries, removing it from OKM statistics");
                delete $libraryGroups->{$categoryCode};
                next();
            }

            #HASHify the branchcodes for easy access
            $libraryGroups->{$categoryCode} = {}; #CategoryCode used to be 1, which makes for a poor HASH reference.
            $libraryGroups->{$categoryCode}->{branches} = {};
            my $branches = $libraryGroups->{$categoryCode}->{branches};
            foreach my $branchcode (@branchcodes){
                grep { $branches->{$_} = 1 } $branchcode->branchcode;
            }
        }
    }
    return $libraryGroups;
}


=head getOKMBranchCategories

    Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM::getOKMBranchCategories();
    $okm->getOKMBranchCategories();

Searches Koha for branchcategories ending to letters "_OKM".
These branchcategories map to a OKM annual statistics row.

@RETURNS a hash of branchcategories.categorycode = 1
=cut

sub getOKMBranchCategories {
    my $self = shift;
    my $libraryGroups = {};

    my @library_categories = Koha::Library::Groups->search({title => {-like => "%_OKM"}});

    foreach my $library_category (@library_categories){
        my $code = $library_category->title;
        $libraryGroups->{$code} = $library_category;
    }
    return $libraryGroups;
}

=head asHtml

    my $html = $okm->asHtml();

Returns an HTML table header and rows for each library group with statistical categories as columns.
=cut

sub asHtml {
    my $self = shift;
    my $libraryGroups = $self->getLibraryGroups();

    my @sb;

    push @sb, '<table>';
    my $firstrun = 1;
    foreach my $groupcode (sort keys %$libraryGroups) {
        my $libraryGroup = $libraryGroups->{$groupcode};
        my $stat = $libraryGroup->getStatistics();

        push @sb, $stat->asHtmlHeader() if $firstrun-- > 0;

        push @sb, $stat->asHtml();
    }
    push @sb, '</table>';

    return join("\n", @sb);
}

=head asCsv

    my $csv = $okm->asCsv();

Returns a csv header and rows for each library group with statistical categories as columns.

@PARAM1 Char, The separator to use to separate columns. Defaults to ','
=cut

sub asCsv {
    my ($self, $separator) = @_;
    my @sb;
    my $a;
    $separator = ',' unless $separator;

    my $libraryGroups = $self->getLibraryGroups();
    
    my $firstrun = 1;
    foreach my $groupcode (sort keys %$libraryGroups) {
        my $libraryGroup = $libraryGroups->{$groupcode};
        my $stat = $libraryGroup->getStatistics();

        push @sb, $stat->asCsvHeader($separator) if $firstrun-- > 0;

        push @sb, $stat->asCsv($separator);
    }

    return join("\n", @sb);
}

=head asOds

=cut

sub asOds {
    my $self = shift;

    my $ods_fh = File::Temp->new( UNLINK => 0 );
    my $ods_filepath = $ods_fh->filename;

    use OpenOffice::OODoc;
    my $tmpdir = dirname $ods_filepath;
    odfWorkingDirectory( $tmpdir );
    my $container = odfContainer( $ods_filepath, create => 'spreadsheet' );
    my $doc = odfDocument (
        container => $container,
        part      => 'content'
    );
    my $table = $doc->getTable(0);
    my $libraryGroups = $self->getLibraryGroups();

    my $firstrun = 1;
    my $row_i = 1;
    foreach my $groupcode (sort keys %$libraryGroups) {
        my $libraryGroup = $libraryGroups->{$groupcode};
        my $stat = $libraryGroup->getStatistics();

        my $headers = $stat->getPrintOrder() if $firstrun > 0;
        my $columns = $stat->getPrintOrderElements();

        if ($firstrun-- > 0) { #Set the table size and print the header!
            $doc->expandTable( $table, scalar(keys(%$libraryGroups))+1, scalar(@$headers) );
            my $row = $doc->getRow( $table, 0 );
            for (my $j=0 ; $j<@$headers ; $j++) {
                $doc->cellValue( $row, $j, $headers->[$j] );
            }
        }

        my $row = $doc->getRow( $table, $row_i++ );
        for (my $j=0 ; $j<@$columns ; $j++) {
            my $value = Encode::encode( 'UTF8', $columns->[$j] );
            $doc->cellValue( $row, $j, $value );
        }
    }

    $doc->save();
    binmode(STDOUT);
    open $ods_fh, '<', $ods_filepath;
    my @content = <$ods_fh>;
    unlink $ods_filepath;
    return join('', @content);
}

=head FindMarcField

Static method

    my $subfieldContent = FindMarcField('041', 'a', $marcxml);

Finds a single subfield effectively.
=cut

sub FindMarcField {
    my ($tagid, $subfieldid, $marcxml) = @_;
    if ($marcxml =~ /<(data|control)field tag="$tagid".*?>(.*?)<\/(data|control)field>/s) {
        my $fieldStr = $2;
        if ($fieldStr =~ /<subfield code="$subfieldid">(.*?)<\/subfield>/s) {
            return $1;
        }
    }
}

=head isItemChildrens

    $row->{location} = 'LAP';
    my $isChildrens = $okm->isItemChildrens($row);
    assert($isChildrens == 1);

@PARAM1 hash, containing the koha.items.location as location-key
=cut

sub isItemChildrens {
    my ($self, $row) = @_;
    my $juvenileShelvingLocations = $self->{conf}->{juvenileShelvingLocations};

    return 1 if $row->{location} && $juvenileShelvingLocations->{$row->{location}};
    return 0;
}

sub isItemFiction {
    my ($self, $cn_sort) = @_;
    if ($cn_sort && $cn_sort =~/^8[0-5].*/) { #ykl numbers 80.* to 85.* are fiction.
        return 1;
    }
    return 0;
}

sub isItemMusical {
    my ($self, $cn_sort) = @_;
    if ($cn_sort && $cn_sort =~/^78.*/) { #ykl numbers 80.* to 85.* are fiction.
        return 1;
    }
    return 0;
}

=head save

    $okm->save();

Serializes this object and saves it to the koha.koha_plugin_fi_kohasuomi_okmstats_okm_statistics-table

@RETURNS the DBI->error() -text.

=cut

sub save {
    my ($self)= @_;
    my @cc = caller(0);
    print '    #'.DateTime->now()->iso8601()."# Starting ".$cc[3]." #\n" if $self->{verbose};

    Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKMLogs::insertLogs($self->flushLogs());
    #Clean some cumbersome Entities which make serialization quite messy.
    $self->{endDate} = undef; #Like DateTime-objects which serialize quite badly.
    $self->{startDate} = undef;

    my $individualbranches = $self->{individualBranches} ? $self->{individualBranches} : "OKM";

    my $lib_groups = $self->{lib_groups};
    my @statistics = ();
    while (my ($key, $value) = each %{$lib_groups}){
        push @statistics, { %{$value->{statistics}} };
    }
    my $json = encode_json(\@statistics);


    #See if this yearly OKM is already serialized
    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare('SELECT id FROM koha_plugin_fi_kohasuomi_okmstats_okm_statistics WHERE startdate = ? AND enddate = ? AND individualbranches = ?');
    $sth->execute( $self->{startDateISO}, $self->{endDateISO}, $individualbranches );
    if ($sth->err) {
        die $cc[3]."():> ".$sth->errstr;
    }
    if (my $id = $sth->fetchrow()) { #Exists in DB
        $sth = $dbh->prepare('UPDATE koha_plugin_fi_kohasuomi_okmstats_okm_statistics SET okm_serialized = ? WHERE id = ?');
        $sth->execute( $json, $id );
    }
    else {
        $sth = $dbh->prepare('INSERT INTO koha_plugin_fi_kohasuomi_okmstats_okm_statistics (startdate, enddate, individualbranches, okm_serialized) VALUES (?,?,?,?)');
        $sth->execute( $self->{startDateISO}, $self->{endDateISO}, $individualbranches, $json );
    }
    if ($sth->err) {
        die $cc[3]."():> ".$sth->errstr;
    }

    return undef;
}

=head Retrieve

    my $okm = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM::Retrieve( $koha_plugin_fi_kohasuomi_okmstats_okm_statisticsId, $startDateISO, $endDateISO, $individualBranches );

Gets an OKM-object from the koha.koha_plugin_fi_kohasuomi_okmstats_okm_statistics-table.
Either finds the OKM-object by the id-column, or by checking the startdate, enddate and individualbranches.
The latter is used when calculating new statistics, and firstly precalculated values are looked for. If a report
matching the given values is found, then we don't need to rerun it.

Generally you should just pass the parameters given to the OKM-object during initialization here to see if a OKM-report already exists.

@PARAM1 long, okm_statistics.id
@PARAM2 ISO8601 datetime, the start of the statistical reporting period.
@PARAM3 ISO8601 datetime, the end of the statistical reporting period.
@PARAM4 Comma-separated String, list of branchcodes to run statistics of if using the librarygroups is not desired.
=cut
sub Retrieve {
    my ($okm_statisticsId, $timeperiod, $individualBranches) = @_;

    my $okm_serialized;
    if ($okm_statisticsId) {
        $okm_serialized = _RetrieveById($okm_statisticsId);
    }
    else {
        my ($startDate, $endDate) = StandardizeTimeperiodParameter($timeperiod);
        $okm_serialized = _RetrieveByParams($startDate->iso8601(), $endDate->iso8601(), $individualBranches);
    }
    return _deserialize($okm_serialized) if $okm_serialized;
    return undef;
}
sub _RetrieveById {
    my ($id) = @_;

    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare('SELECT okm_serialized FROM koha_plugin_fi_kohasuomi_okmstats_okm_statistics WHERE id = ?');
    $sth->execute( $id );
    return $sth->fetchrow();
}
sub _RetrieveByParams {
    my ($startDateISO, $endDateISO, $individualBranches) = @_;

    my $dbh = C4::Context->dbh();
    # $individualBranches might be undef. DBI doesn't handle undef values well so check is needed.
    # https://metacpan.org/pod/DBI#SQL-A-Query-Language
    my $individualBranches_clause = defined $individualBranches? "individualbranches = ?" : "individualbranches IS NULL";
    my $sth = $dbh->prepare(qq{SELECT okm_serialized FROM koha_plugin_fi_kohasuomi_okmstats_okm_statistics WHERE startdate = ? AND enddate = ? AND $individualBranches_clause});
    $sth->execute( $startDateISO, $endDateISO, defined $individualBranches ? $individualBranches : () );
    return $sth->fetchrow();
}
sub RetrieveAll {
    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare('SELECT * FROM koha_plugin_fi_kohasuomi_okmstats_okm_statistics ORDER BY enddate DESC');
    $sth->execute(  );
    return $sth->fetchall_arrayref({});
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
=head Delete

    Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM::Delete($id);

@PARAM1 Long, The koha.koha_plugin_fi_kohasuomi_okmstats_okm_statistics.id of the statistical row to delete.
@RETURNS DBI::Error if database errors, otherwise undef.
=cut
sub Delete {
    my $id = shift;

    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare('DELETE FROM koha_plugin_fi_kohasuomi_okmstats_okm_statistics WHERE id = ?');
    $sth->execute( $id );
    if ( $sth->err ) {
        return $sth->err;
    }
    return undef;
}

=head _loadConfiguration

    $self->_loadConfiguration();

Loads the configuration YAML from sysprefs and parses it to a Hash.
=cut

sub loadConfiguration {
    my ($self) = @_;

    my $yaml = Koha::Plugin::Fi::KohaSuomi::OKMStats->new()->retrieve_data('okm_syspref');

    utf8::encode( $yaml );
    $self->{conf} = YAML::XS::Load($yaml);

    ##Make 'juvenileShelvingLocations' more searchable
    my $juvShelLocs = $self->{conf}->{juvenileShelvingLocations};
    $self->{conf}->{juvenileShelvingLocations} = {};
    foreach my $loc (@{$juvShelLocs}) {
        $self->{conf}->{juvenileShelvingLocations}->{$loc} = 1;
    }

    $self->_validateConfigurationAndPreconditions();
    $self->_makeStatisticalCategoryToItemTypesMap();
}

=head getItemtypesByStatisticalCategories

    my $categories = $self->getItemtypesByStatisticalCategories('Electronic');

Fetch all itemtypes belonging to the statical category. Returns an array.
=cut

sub getItemtypesByStatisticalCategories {
    my ($self, @statCats) = @_;
    my @itypes;
    foreach my $sc (@statCats) {
        my $category = $self->{conf}->{statisticalCategoryToItemTypes}->{$sc};
        if($category){
            push(@itypes, @{$category});
        }
    }
    return \@itypes;
}

=head _validateConfigurationAndPreconditions
Since this is a bit complex feature. Check for correct configurations here.
Also make sure system-wide preconditions and precalculations are in place.
=cut

sub _validateConfigurationAndPreconditions {
    my ($self) = @_;

    ##Make sanity checks for the config and throw an error to tell the user that the config needs fixing.
    my @statCatKeys = ();
    my @juvenileShelLocKeys = ();
    if (ref $self->{conf}->{itemTypeToStatisticalCategory} eq 'HASH') {
        @statCatKeys = keys(%{$self->{conf}->{itemTypeToStatisticalCategory}});
    }
    if (ref $self->{conf}->{juvenileShelvingLocations} eq 'HASH') {
        @juvenileShelLocKeys = keys(%{$self->{conf}->{juvenileShelvingLocations}});
    }
    unless (scalar(@statCatKeys)) {
        my @cc = caller(0);
        die $cc[3]."():> System preference 'OKM' is missing YAML-parameter 'itemTypeToStatisticalCategory'.\n".
                     "It should look something like this: \n".
                     "itemTypeToStatisticalCategory: \n".
                     "  BK: Books \n".
                     "  MU: Recordings \n";
    }
    unless (scalar(@juvenileShelLocKeys)) {
        my @cc = caller(0);
        die $cc[3]."():> System preference 'OKM' is missing YAML-parameter 'juvenileShelvingLocations'.\n".
                     "It should look something like this: \n".
                     "juvenileShelvingLocations: \n".
                     "  - CHILD \n".
                     "  - AV \n";
    }
    
    my @authorised_values_by_category = Koha::AuthorisedValues->search( { category => 'MTYPE' } );

    my @loop_data = ();
    # builds value list
    for my $av ( @authorised_values_by_category ) {
        my %row_data;  # get a fresh hash for the row data
        $row_data{authorised_value}      = $av->authorised_value;
        push(@loop_data, \%row_data);
    }

    my $itemcount = scalar (@loop_data);

    my @itypes = ();

    for (my $i=0; $i < $itemcount; $i++) {
      push ( @itypes, $loop_data [$i]{authorised_value} );
   }

    ##Check that we haven't accidentally mapped any itemtypes that don't actually exist in our database
    my %mappedItypes = map {$_ => 1} @statCatKeys; #Copy the itemtypes-as-keys
    my @preconditionerr = ();

    ##Check that all itemtypes and statistical categories are mapped
    ##when set to 0, statistical category must be used
    my %statCategories = ( "Books" => 1, "SheetMusicAndScores" => 1,
                        "Recordings" => 1, "Videos" => 1, "Other" => 1,
                        "Celia" => 1, "Online" => 1, "Electronic" => 1,
                        "Serials" => 1);
    
    foreach my $itype (@itypes) {
            my $mapping = $self->{conf}->{itemTypeToStatisticalCategory}->{$itype};
            unless ($mapping) { #Is itemtype mapped?
                my @cc = caller(0);
                push (@preconditionerr, $cc[3]."():> System preference 'OKM' has an unmapped itemtype '" . $itype . "'. Put it under 'itemTypeToStatisticalCategory'."."\n");
            }
            else {
                delete $mappedItypes{$itype};
            }
            if(exists($statCategories{$mapping})) {
                $statCategories{$mapping} = 1; #Mark this mapping as used.
            }
            else { #Do we have extra statistical mappings we dont care of?
               my @cc = caller(0);
               my @statCatKeys = keys(%statCategories);
               push (@preconditionerr, $cc[3]."():> System preference 'OKM' has an unknown mapping '$mapping'. Allowed statistical categories under 'itemTypeToStatisticalCategory' are @statCatKeys");
            } 
    }
    
    
    #Do we have extra mapped item types?
    if (scalar(keys(%mappedItypes))) {
        #my @cc = caller(0);
        my @itypes = keys(%mappedItypes);
        my @cc = caller(0);
        push (@preconditionerr, $cc[3]."():> System preference 'OKM' has mapped itemtypes '@itypes' that don't exist in your authorized value MTYPE.");
    }

    #Check that all statistical categories are mapped
    while (my ($k, $v) = each(%statCategories)) {
        unless ($v) {
            my @cc = caller(0);
            push (@preconditionerr, $cc[3]."():> System preference 'OKM' has an unmapped statistical category '$k'. Map it to the 'itemTypeToStatisticalCategory'");
        }
    }

    #Show all errors
    if (@preconditionerr) {
        die "@preconditionerr";
    }
}

sub _makeStatisticalCategoryToItemTypesMap {
    my ($self) = @_;
    my %statisticalCategoryToItemTypes;
    while (my ($itype, $statCat) = each(%{$self->{conf}->{itemTypeToStatisticalCategory}})) {
        $statisticalCategoryToItemTypes{$statCat} = [] unless $statisticalCategoryToItemTypes{$statCat};
        push(@{$statisticalCategoryToItemTypes{$statCat}}, $itype);
    }
    $self->{conf}->{statisticalCategoryToItemTypes} = \%statisticalCategoryToItemTypes;
}

=head StandardizeTimeperiodParameter

    my ($startDate, $endDate) = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM::StandardizeTimeperiodParameter($timeperiod);

@PARAM1 String, The timeperiod definition. Supported values are:
                1. "YYYY-MM-DD - YYYY-MM-DD" (start to end, inclusive)
                   "YYYY-MM-DDThh:mm:ss - YYYY-MM-DDThh:mm:ss" is also accepted, but only the YYYY-MM-DD-portion is used.
                2. "YYYY" (desired year)
                3. "MM" (desired month, of the current year)
                4. "lastyear" (Calculates the whole last year)
                5. "lastmonth" (Calculates the whole previous month)
                Kills the process if no timeperiod is defined or if it is unparseable!
@RETURNS Array of DateTime, or die
=cut
sub StandardizeTimeperiodParameter {
    my ($timeperiod) = @_;

    my ($startDate, $endDate);

    if ($timeperiod =~ /^(\d\d\d\d)-(\d\d)-(\d\d)([Tt ]\d\d:\d\d:\d\d)?-(\d\d\d\d)-(\d\d)-(\d\d)([Tt ]\d\d:\d\d:\d\d)?$/) {
        #Make sure the values are correct by casting them into a DateTime
        $startDate = DateTime->new(year => $1, month => $2, day => $3, time_zone => C4::Context->tz());
        $endDate = DateTime->new(year => $5, month => $6, day => $7, time_zone => C4::Context->tz());
    }
    elsif ($timeperiod =~ /^(\d\d\d\d)$/) {
        $startDate = DateTime->from_day_of_year(year => $1, day_of_year => 1, time_zone => C4::Context->tz());
        $endDate = ($startDate->is_leap_year()) ?
                            DateTime->from_day_of_year(year => $1, day_of_year => 366, time_zone => C4::Context->tz()) :
                            DateTime->from_day_of_year(year => $1, day_of_year => 365, time_zone => C4::Context->tz());
    }
    elsif ($timeperiod =~ /^(\d\d)$/) {
        $startDate = DateTime->new( year => DateTime->now()->year(),
                                    month => $1,
                                    day => 1,
                                    time_zone => C4::Context->tz(),
                                   );
        $endDate = DateTime->last_day_of_month( year => $startDate->year(),
                                                month => $1,
                                                time_zone => C4::Context->tz(),
                                              ) if $startDate;
    }
    elsif ($timeperiod =~ 'lastyear') {
        $startDate = DateTime->now(time_zone => C4::Context->tz())->subtract(years => 1)->set_month(1)->set_day(1);
        $endDate = ($startDate->is_leap_year()) ?
                DateTime->from_day_of_year(year => $startDate->year(), day_of_year => 366, time_zone => C4::Context->tz()) :
                DateTime->from_day_of_year(year => $startDate->year(), day_of_year => 365, time_zone => C4::Context->tz()) if $startDate;
    }
    elsif ($timeperiod =~ 'lastmonth') {
        $startDate = DateTime->now(time_zone => C4::Context->tz())->subtract(months => 1)->set_day(1);
        $endDate = DateTime->last_day_of_month( year => $startDate->year(),
                                                month => $startDate->month(),
                                                time_zone => $startDate->time_zone(),
                                              ) if $startDate;
    }

    if ($startDate && $endDate) {
        #Check if startdate is smaller than enddate, if not fix it.
        if (DateTime->compare($startDate, $endDate) == 1) {
            my $temp = $startDate;
            $startDate = $endDate;
            $endDate = $temp;
        }

        #Make sure the HMS portion also starts from 0 and ends at the end of day. The DB usually does timeformat casting in such a way that missing
        #complete DATETIME elements causes issues when they are automaticlly set to 0.
        $startDate->truncate(to => 'day');
        $endDate->set_hour(23)->set_minute(59)->set_second(59);
        return ($startDate, $endDate);
    }
    die "OKM->_standardizeTimeperiodParameter($timeperiod): Timeperiod '$timeperiod' could not be parsed.";
}

=head log

    $okm->log("Something is wrong, why don't you fix it?");
    my $logArray = $okm->getLog();

=cut

sub log {
    my ($self, $message) = @_;
    push @{$self->{logs}}, $message;
    print $message."\n" if $self->{verbose};
}

sub flushLogs {
    my ($self) = @_;
    my $logs = $self->{logs};
    delete $self->{logs};
    return $logs;
}

1;