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

Finds all biblioitems that have changed since the last time koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements has been updated.
Extracts koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements from those MARCXMLs'.
@PARAM1, Boolean, should we UPDATE all biblioitems BiblioDataElements or simply increment changes?
@PARAM2, Int, the SQL LIMIT-clause, or undef.
@PARAM3, Int, verbosity level. See update_biblio_data_elements.pl-cronjob
=cut

sub UpdateBiblioDataElements {
    my ($forceRebuild, $limit, $verbose, $oldDbi) = @_;

    $verbose = 0 unless $verbose; #Prevent undefined comparison errors

    if ($forceRebuild) {
        forceRebuild($limit, $verbose, $oldDbi);
    }
    else {
        try {
            my $biblioitems = _getBiblioitemsNeedingUpdate($limit, $verbose);

            if ($biblioitems && ref $biblioitems eq 'ARRAY') {
                print "Found '".scalar(@$biblioitems)."' biblioitems-records to update.\n" if $verbose > 0;
                foreach my $biblioitem (@$biblioitems) {
                    eval {
                        UpdateBiblioDataElement($biblioitem, $verbose, $oldDbi);
                    };
                    warn $@ if $@;
                }
            }
            elsif ($verbose > 0) {
                print "Nothing to UPDATE\n";
            }
        } catch {
            if (blessed($_) && $_->isa('Koha::Exceptions::Exception')) {
                forceRebuild($limit, $verbose, $oldDbi);
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
    my ($limit, $verbose, $oldDbi) = @_;

    $verbose = 0 unless $verbose; #Prevent undefined comparison errors

    my $chunker = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::Chunker->new(undef, $limit, undef, $verbose);
    while (my $biblioitems = $chunker->getChunk(undef, $limit)) {
        foreach my $biblioitem (@$biblioitems) {
            eval {
                UpdateBiblioDataElement($biblioitem, $verbose, $oldDbi);
            };
            warn $@ if $@;
        }
    }
}
=head UpdateBiblioDataElement

    Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElements::UpdateBiblioDataElement($biblioitem, $verbose);

Takes biblioitems and MARCXML and picks the needed data_elements to the koha.biblio_data_elements -table.
@PARAM1, Koha::Biblioitem or a HASH of koha.biblioitems-row.
@PARAM2, Int, verbosity level. See update_biblio_data_elements.pl-cronjob

=cut

sub UpdateBiblioDataElement {
    my ($biblioitem, $verbose) = @_;
    $verbose = 0 unless $verbose; #Prevent undef errors

    my $deleted = $biblioitem->{deleted};
    my $itemtype = $biblioitem->{itemtype};
    my $biblioitemnumber = $biblioitem->{biblioitemnumber};

    my $bde = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement::DBI_getBiblioDataElement($biblioitem->{biblioitemnumber});
    $bde = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement->new({biblioitemnumber => $biblioitemnumber}) if (not($bde));

    #Make a MARC::Record out of the XML.
    my $marcxml = $deleted ? _getDeletedXmlBiblio( $biblioitem->{biblionumber} ) : C4::Biblio::GetXmlBiblio( $biblioitem->{biblionumber} );
    my $record = eval { MARC::Record::new_from_xml( $marcxml, "utf8", C4::Context->preference('marcflavour') ) };
    if ($@) {
        die $@;
    }
    #Start creating data_elements.
    $bde->isBiblioitemFiction($record, $biblioitem->{cn_sort});
    $bde->isMusicalRecording($record);
    $bde->isCelia($record);
    $bde->setDeleted($deleted, $biblioitem->{timestamp});
    $bde->setItemtype($itemtype);
    $bde->isComponentPart($biblioitem->{biblionumber});
    $bde->isSerial($itemtype);
    $bde->setLanguages($record);
    $bde->setEncodingLevel($record);

    if($bde->{biblioitemnumber}){
        Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement::DBI_updateBiblioDataElement($bde)
    } else {
        Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement::DBI_insertBiblioDataElement($bde, $biblioitemnumber);
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

=head _getBiblioitemsNeedingUpdate
Finds the biblioitems whose timestamp (time last modified) is bigger than the biggest last_mod_time in koha.biblio_data_elements
=cut

sub _getBiblioitemsNeedingUpdate {
    my ($limit, $verbose) = @_;
    my @cc = caller(0);

    if ($limit) {
        $limit = " LIMIT $limit ";
        $limit =~ s/;//g; #Evade SQL injection :)
    }
    else {
        $limit = '';
    }

    print '#'.DateTime->now(time_zone => C4::Context->tz())->iso8601().'# Fetching biblioitems  #'."\n" if $verbose > 0;

    my $lastModTime = GetLatestDataElementUpdateTime($verbose) || Koha::Exceptions::Exception->throw($cc[3]."():> You must do a complete rebuilding since none of the biblios have been indexed yet.");
    $lastModTime = $lastModTime->iso8601();

    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare("
            (SELECT bi.biblioitemnumber, bi.biblionumber, bi.itemtype, 0 AS deleted FROM biblioitems bi
             LEFT JOIN biblio_metadata bmd ON(bi.biblionumber = bmd.biblionumber)
             WHERE bi.timestamp >= '". $lastModTime ."'
             OR bmd.timestamp >= '". $lastModTime ."' $limit
            ) UNION (
             SELECT dbi.biblioitemnumber, dbi.biblionumber, dbi.itemtype, 1 AS deleted FROM deletedbiblioitems dbi
             LEFT JOIN deletedbiblio_metadata dbmd ON(dbi.biblionumber = dbmd.biblionumber)
             WHERE dbi.timestamp >= '". $lastModTime ."'
             OR dbmd.timestamp >= '". $lastModTime ."' $limit
            )
    ");
    $sth->execute();
    if ($sth->err) {
        die $cc[3]."():> ".$sth->errstr;
    }
    my $biblioitems = $sth->fetchall_arrayref({});

    print '#'.DateTime->now(time_zone => C4::Context->tz())->iso8601().'# Biblioitems fetched #'."\n" if $verbose > 0;

    return $biblioitems;
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
