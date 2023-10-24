package Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElements;

# Copyright Vaara-kirjastot 2015
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
use Carp;
use DateTime;
use DateTime::Format::HTTP;
use Try::Tiny;
use Scalar::Util qw(blessed);
use MARC::Record;
use MARC::File::XML;

use Koha::Database;

use Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::Chunker;
use Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement;

use base qw(Koha::Objects);

sub _type {
    return 'BiblioDataElement';
}

sub object_class {
    return 'Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement';
}

=head UpdateBiblioDataElements

    Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElements::UpdateBiblioDataElements([$limit]);

Finds all biblios that have changed since the last time koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements has been updated.
Extracts koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements from those MARCXMLs'.
@PARAM1, Boolean, should we UPDATE all biblios BiblioDataElements or simply increment changes?
@PARAM2, Int, the SQL LIMIT-clause, or undef.
@PARAM3, Int, verbosity level. See update_biblio_data_elements.pl-cronjob
=cut

sub UpdateBiblioDataElements {
    my ($forceRebuild, $limit, $verbose, $biblionumber) = @_;

    $verbose = 0 unless $verbose; #Prevent undefined comparison errors

    if ($forceRebuild) {
        forceRebuild($limit, $verbose);
    } elsif ($biblionumber) {
        my $biblio = get_single_biblio($biblionumber, $verbose);
        eval {
            UpdateBiblioDataElement($biblio, $verbose);
        };
        warn $@ if $@;
    }
    else {
        try {
            my $biblios = _get_biblios_needing_update($limit, $verbose);

            if ($biblios && ref $biblios eq 'ARRAY') {
                print "Found '".scalar(@$biblios)."' biblio-records to update.\n" if $verbose > 0;
                foreach my $biblio (@$biblios) {
                    eval {
                        UpdateBiblioDataElement($biblio, $verbose);
                    };
                    warn $@ if $@;
                }
            }
            elsif ($verbose > 0) {
                print "Nothing to UPDATE\n";
            }
        } catch {
            if (blessed($_) && $_->isa('Koha::Exceptions::Exception')) {
                forceRebuild($limit, $verbose);
            }
            elsif (blessed($_)) {
                $_->rethrow();
            }
            else {
                die $_;
            }
        };
    }
}

sub forceRebuild {
    my ($limit, $verbose) = @_;

    $verbose = 0 unless $verbose; #Prevent undefined comparison errors
    my $chunker = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::Chunker->new(undef, $limit, undef, $verbose);
    while (my $biblios = $chunker->getChunk(undef, $limit)) {
        foreach my $biblio (@$biblios) {
            eval {
                UpdateBiblioDataElement($biblio, $verbose);
            };
            warn $@ if $@;
        }
    }
}
=head UpdateBiblioDataElement

    Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElements::UpdateBiblioDataElement($biblio, $verbose);

Takes biblios and MARCXML and picks the needed data_elements to the koha.biblio_data_elements -table.
@PARAM1, Koha::Biblio or a HASH of koha.biblios-row.
@PARAM2, Int, verbosity level. See update_biblio_data_elements.pl-cronjob

=cut

sub UpdateBiblioDataElement {
    my ($biblio, $verbose) = @_;
    $verbose = 0 unless $verbose; #Prevent undef errors

    my $deleted = $biblio->{deleted};
    my $biblionumber = $biblio->{biblionumber};
    my $biblioitemnumber = $biblio->{biblioitemnumber};

    my $bde = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement::DBI_getBiblioDataElement($biblionumber);
    $bde = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement->new({biblionumber => $biblionumber}) if (not($bde));

    #Make a MARC::Record out of the XML.
    my $marcxml = $deleted ? _getDeletedXmlBiblio( $biblionumber ) : C4::Biblio::GetXmlBiblio( $biblionumber );
    my $record = eval { MARC::Record::new_from_xml( $marcxml, "utf8", C4::Context->preference('marcflavour') ) };
    if ($@) {
        die $@;
    }
    #Start creating data_elements.
    $bde->isBiblioFiction($record);
    $bde->isMusicalRecording($record);
    $bde->isCelia($record);
    $bde->setDeleted($deleted, $biblio->{timestamp});
    $bde->setItemtype($record);
    $bde->isComponentPart($record);
    $bde->setLanguages($record);
    $bde->setCnClass($record);
    $bde->setGenres($record);
    $bde->set_publication_year($record);

    if($bde->{biblionumber}){
        Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement::DBI_updateBiblioDataElement($bde)
    } else {
        Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement::DBI_insertBiblioDataElement($bde, $biblionumber, $biblioitemnumber);
    }
}

=head GetLatestDataElementUpdateTime

    Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElements::GetLatestDataElementUpdateTime($forceRebuild, $verbose);

Finds the last time koha.biblio_data_elements has been UPDATED.
If the table is empty, returns undef
@PARAM1, Int, verbosity level. See update_biblio_data_elements.pl-cronjob
@RETURNS DateTime or undef
=cut
sub GetLatestDataElementUpdateTime {
    my ($verbose) = @_;
    my $dbh = C4::Context->dbh();
    my $sthLastModTime = $dbh->prepare("SELECT MAX(last_mod_time) as last_mod_time FROM koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements;");
    $sthLastModTime->execute( );
    my $rv = $sthLastModTime->fetchrow_hashref();
    my $lastModTime = ($rv && $rv->{last_mod_time}) ? $rv->{last_mod_time} : undef;
    print "Latest koha.koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements updating time '".($lastModTime || '')."'\n" if $verbose > 0;
    return undef if(not($lastModTime) || $lastModTime =~ /^0000-00-00/);
    my $dt = DateTime::Format::HTTP->parse_datetime($lastModTime);
    $dt->set_time_zone( C4::Context->tz() );
    return $dt;
}

=head _get_biblios_needing_update
Finds the biblios whose timestamp (time last modified) is bigger than the biggest last_mod_time
in koha.koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements or which we can't find from
koha.koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements
=cut

sub _get_biblios_needing_update {
    my ($limit, $verbose) = @_;
    my @cc = caller(0);

    if ($limit) {
        $limit = " LIMIT $limit ";
        $limit =~ s/;//g; #Evade SQL injection :)
    }
    else {
        $limit = '';
    }

    print '#'.DateTime->now(time_zone => C4::Context->tz())->iso8601().'# Fetching biblios  #'."\n" if $verbose > 0;

    my $lastModTime = GetLatestDataElementUpdateTime($verbose) || Koha::Exceptions::Plugin->throw($cc[3]."():> You must do a complete rebuilding since none of the biblios have been indexed yet.");
    $lastModTime = $lastModTime->iso8601();

    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare("
            (SELECT b.biblionumber, bi.biblioitemnumber, 0 AS deleted FROM biblio b
             LEFT JOIN biblioitems bi ON(bi.biblionumber = b.biblionumber)
             LEFT JOIN biblio_metadata bmd ON(b.biblionumber = bmd.biblionumber)
             WHERE b.timestamp >= '". $lastModTime ."'
             OR bmd.timestamp >= '". $lastModTime ."'
             OR b.biblionumber NOT IN(SELECT biblionumber FROM koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements) $limit
            ) UNION (
             SELECT db.biblionumber, dbi.biblioitemnumber, 1 AS deleted FROM deletedbiblio db
             LEFT JOIN deletedbiblioitems dbi ON(dbi.biblionumber = db.biblionumber)
             LEFT JOIN deletedbiblio_metadata dbmd ON(db.biblionumber = dbmd.biblionumber)
             WHERE db.timestamp >= '". $lastModTime ."'
             OR dbmd.timestamp >= '". $lastModTime ."'
             OR db.biblionumber NOT IN(SELECT biblionumber FROM koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements) $limit
            )
    ");
    $sth->execute();
    if ($sth->err) {
        die $cc[3]."():> ".$sth->errstr;
    }
    my $biblios = $sth->fetchall_arrayref({});

    print '#'.DateTime->now(time_zone => C4::Context->tz())->iso8601().'# Biblios fetched #'."\n" if $verbose > 0;

    return $biblios;
}

sub get_single_biblio {
    my ($biblionumber, $verbose) = @_;
    my @cc = caller(0);

    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare("
            (SELECT b.biblionumber, bi.biblioitemnumber, 0 AS deleted FROM biblio b
             LEFT JOIN biblioitems bi ON(bi.biblionumber = b.biblionumber)
             WHERE b.biblionumber = $biblionumber
            ) UNION (
             SELECT b.biblionumber, bi.biblioitemnumber, 1 AS deleted FROM deletedbiblio b
             LEFT JOIN deletedbiblioitems bi ON(bi.biblionumber = b.biblionumber)
             WHERE b.biblionumber = $biblionumber
            )
    ");
    $sth->execute();
    if ($sth->err) {
        die $cc[3]."():> ".$sth->errstr;
    }
    my $biblio = $sth->fetchrow_hashref;

    return $biblio;
}

=head verifyFeatureIsInUse

    my $ok = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElements::verifyFeatureIsInUse($verbose);

@PARAM1 Integer, see --verbose in update_biblio_data_elements.pl
@RETURNS Flag, 1 if this feature is properly configured
@THROWS error and dies if this feature is not in use.
=cut

sub verifyFeatureIsInUse {
    my ($verbose) = @_;
    $verbose = 0 unless $verbose;

    my $now = DateTime->now(time_zone => C4::Context->tz());
    my $lastUpdateTime = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElements::GetLatestDataElementUpdateTime($verbose) || DateTime::Format::HTTP->parse_datetime('1900-01-01 01:01:01');
    my $difference = $now->subtract_datetime( $lastUpdateTime );
    if (($difference->in_units( 'days' ) > 2) && $verbose) {
        my @cc = caller(0);
        die $cc[3]."():> koha.biblio_data_elements-table is stale. You must configure cronjob 'update_biblio_data_elements.pl' to run daily.";
    }
    elsif ($difference->in_units( 'days' ) > 2) {
        return 0;
    }
    else {
        return 1;
    }
}

=head markForReindex

    Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElements::markForReindex();

Marks all BiblioDataElements to be updated during the next indexing.

=cut

sub markForReindex {
    my $dbh = C4::Context->dbh();
    $dbh->do("UPDATE koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements SET last_mod_time = '1900-01-01 01:01:01'");
}

=head _getDeletedXmlBiblio

An ugly copypaste of GetXmlBiblio since GetDeletedXmlBiblio doesn't exists on community version.

=cut

sub _getDeletedXmlBiblio {
    my ($biblionumber) = @_;
    my $dbh = C4::Context->dbh;
    return unless $biblionumber;
    my ($marcxml) = $dbh->selectrow_array(
        q|
        SELECT metadata
        FROM deletedbiblio_metadata
        WHERE biblionumber=?
            AND format='marcxml'
            AND `schema`=?
    |, undef, $biblionumber, C4::Context->preference('marcflavour')
    );
    return $marcxml;
}

1;
