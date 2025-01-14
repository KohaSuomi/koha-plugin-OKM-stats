package Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement;

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

use Koha::Database;
use Koha::DateUtils;

use Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM;

use base qw(Koha::Object);

sub _type {
    return 'BiblioDataElement';
}

sub isBiblioFiction {
    my ($self, $record) = @_;
    my $col = 'fiction';

    my $sf = $record->subfield('084','a');
    my $val = ($sf && $sf =~/^8[0-5].*/) ? 1 : 0;

    ($self->{dbi}) ? $self->{$col} = $val : $self->set({$col => $val});
}

sub isMusicalRecording {
    my ($self, $record) = @_;
    my $col = 'musical';

    my $sf = $record->subfield('084','a');
    my $val = ($sf && $sf =~/^78.*/) ? 1 : 0;

    ($self->{dbi}) ? $self->{$col} = $val : $self->set({$col => $val});
}

sub isCelia {
    my ($self, $record) = @_;

    my $col = 'celia';

    my $sf = $record->subfield('599','a');
    my $val = ($sf && $sf =~/^Daisy/) ? 1 : 0;

    ($self->{dbi}) ? $self->{$col} = $val : $self->set({$col => $val});
}

sub isComponentPart {
    my ($self, $record) = @_;
    my $col = 'host_record';

    my $host_record = $record ? get_host_record($record) : undef;
    my $val = $host_record ? $host_record->subfield('999', 'c') : undef;

    ($self->{dbi}) ? $self->{$col} = $val : $self->set({$col => $val});
}

sub setItemtype {
    my ($self, $record) = @_;
    my $col = 'itemtype';

    my $val = $record->subfield('942', 'c');

    ($self->{dbi}) ? $self->{$col} = $val : $self->set({$col => $val});
}

=head set_primary_language

    $bde->set_primary_language($record);

Sets the primary_language column.
Defaults to "OTH" if fields 008 or 041 do not contain acceptable
string (3 character long, contains only alphabets).

@PARAM1, MARC::Record

=cut

sub set_primary_language {
    my ($self, $record) = @_;
    my $f008 = $record->field('008');
    my $primaryLanguage = 'OTH';

    if( $f008 && substr($f008->data(), 35, 3) && ( substr($f008->data(), 35, 3) =~ /(.*[a-zA-Z]){3}/ )) {
        $primaryLanguage = substr($f008->data(), 35, 3);
    } elsif ( $record->subfield('041', 'a') && ( $record->subfield('041', 'a') =~ /(.*[a-zA-Z]){3}/ ) ) {
        $primaryLanguage = $record->subfield('041', 'a');
    } elsif ( $record->subfield('041', 'd') && ( $record->subfield('041', 'd') =~ /(.*[a-zA-Z]){3}/ ) ) {
        $primaryLanguage = $record->subfield('041', 'd');
    }

    ($self->{dbi}) ? $self->{'primary_language'} = $primaryLanguage : $self->set({'primary_language' => $primaryLanguage});
}

=head set_languages

    $bde->set_language($record);

Sets the languages column.
Collects all 041 fields.

@PARAM1, MARC::Record

=cut

sub set_languages {
    my ($self, $record) = @_;

    my $languages = '';
    my @sb; #StrinBuilder to efficiently collect language Strings and concatenate them
    my $f041 = $record->field('041');

    if ($f041) {
        my @sfs = $f041->subfields();
        @sfs = sort {$a->[0] cmp $b->[0]} @sfs;
        foreach my $sf (@sfs) {
            unless (ref $sf eq 'ARRAY' && $sf->[0] && $sf->[1]) { #Code to fail :)
                next;
            }
            push @sb, $sf->[0].':'.$sf->[1];

        }
        $languages = join(',',@sb) if scalar(@sb);
    }

    ($self->{dbi}) ? $self->{'languages'} = $languages : $self->set({'languages' => $languages});
}

sub set_deleted {
    my ($self, $deleted) = @_;
    my $col = 'deleted';

    ($self->{dbi}) ? $self->{$col} = $deleted : $self->set({$col => $deleted});
}

sub set_deleted_on {
    my ($self, $timestamp) = @_;
    my $col = 'deleted_on';

    ($self->{dbi}) ? $self->{$col} = $timestamp : $self->set({$col => $timestamp});
}

sub setCnClass {
    my ($self, $record) = @_;
    my $col = 'cn_class';

    my $val = $record->subfield('084', 'a');

    ($self->{dbi}) ? $self->{$col} = $val : $self->set({$col => $val});
}

sub setGenres {
    my ($self, $record) = @_;
    my $col = 'genres';

    my @f084 = $record->field('084');
    my $genres;
    my @genre_string;

    if ( @f084 ){
        foreach my $field (@f084) {
            if($field->indicator(1) eq "9"){
                my $genre = $field->subfield("a");
                push @genre_string, $genre;
            }
        }
        $genres = join(',',@genre_string) if scalar(@genre_string);
    }

    my $val = $genres;

    ($self->{dbi}) ? $self->{$col} = $val : $self->set({$col => $val});
}

sub set_publication_year {
    my ($self, $record) = @_;
    my $col = 'publication_year';

    my $f008 = $record->field('008');
    my $val = substr($f008->data(), 7, 4) if $f008;

    ($self->{dbi}) ? $self->{$col} = $val : $self->set({$col => $val});
}

sub get_host_record {
    my ($record) = @_;

    my $f773w = $record->subfield('773', 'w');
    my $f003;
    if ($f773w && $f773w =~ /\((.*)\)/ ) {
        $f003 = $1;
        $f773w =~ s/\D//g;
    }
    my $cn = $f773w;
    $f003 = $record->field('003');
    my $cni = $f003->data() if $f003;

    return undef unless $cn && $cni;

    my $query = "Control-number,ext:\"$cn\" AND cni,ext:\"$cni\"";
    require Koha::SearchEngine::Search;

    my $searcher = Koha::SearchEngine::Search->new({index => $Koha::SearchEngine::BIBLIOS_INDEX});

    my ( $error, $results, $total_hits ) = $searcher->simple_search_compat( $query, 0, 10 );
    if ($error) {
        die "get_host_record():> Searching ($query):> Returned an error:\n$error";
    }

    my $marcflavour = C4::Context->preference('marcflavour');

    if ($total_hits == 1) {
        my $record = $results->[0];
        return ref($record) ne 'MARC::Record' ? MARC::Record::new_from_xml($record, 'UTF-8', $marcflavour) : $record;
    }
    elsif ($total_hits > 1) {
        die "get_host_record():> Searching ($query):> Returned more than one record?";
    }
    return undef;
}

=head PERFORMANCE IMPROVEMENT TESTS USING DBI

    THIS MODULE IS SUPER SLOW, LOOKING TO SPEED IT USING plain DBI

=cut

sub DBI_new {
    my ($class, $bdeHash, $biblionumber) = @_;
    unless ($bdeHash && ref $bdeHash eq 'HASH') {
        $bdeHash = {};
    }
    bless($bdeHash, $class);
    $bdeHash->{dbi} = 1;
    return $bdeHash;
}

sub DBI_getBiblioDataElement {
    my ($biblionumber) = @_;
    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare("
        SELECT * FROM koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements
        WHERE biblionumber = ?;
    ");
    $sth->execute( $biblionumber );
    if ($sth->err) {
        my @cc = caller(0);
        die $cc[3]."():> ".$sth->errstr;
    }
    my $bde = $sth->fetchrow_hashref();
    return Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement->DBI_new($bde, $biblionumber);
}

sub DBI_updateBiblioDataElement {
    my ($bde) = @_;
    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare("
        UPDATE koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements
        SET deleted = ?,
            deleted_on = ?,
            primary_language = ?,
            languages = ?,
            fiction = ?,
            cn_class = ?,
            genres = ?,
            musical = ?,
            celia = ?,
            publication_year = ?,
            itemtype = ?,
            host_record = ?
        WHERE biblionumber = ?;
    ");
    $sth->execute( $bde->{deleted}, $bde->{deleted_on}, $bde->{primary_language}, $bde->{languages}, $bde->{fiction}, $bde->{cn_class}, $bde->{genres}, $bde->{musical}, $bde->{celia}, $bde->{publication_year}, $bde->{itemtype}, $bde->{host_record}, $bde->{biblionumber} );
    if ($sth->err) {
        my @cc = caller(0);
        die $cc[3]."():> ".$sth->errstr;
    }
}

sub DBI_insertBiblioDataElement {
    my ($bde, $biblionumber, $biblioitemnumber) = @_;
    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare("
        INSERT INTO koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements
            (biblionumber, biblioitemnumber, deleted, deleted_on, primary_language, languages, fiction, cn_class, genres, musical, celia, publication_year, itemtype, host_record)
            VALUES
            (?,            ?               , ?      , ?         , ?               , ?        , ?      , ?       , ?    , ?      , ?    , ?               , ?       , ?);
    ");
    $sth->execute( $biblionumber, $biblioitemnumber, $bde->{deleted}, $bde->{deleted_on}, $bde->{primary_language}, $bde->{languages}, $bde->{fiction}, $bde->{cn_class}, $bde->{genres}, $bde->{musical}, $bde->{celia}, $bde->{publication_year}, $bde->{itemtype}, $bde->{host_record} );
    if ($sth->err) {
        my @cc = caller(0);
        die $cc[3]."():> ".$sth->errstr;
    }
}

sub dbi_update_single_column {
    my ($biblionumber, $column, $value) = @_;
    if( $value ){
        my $dbh = C4::Context->dbh();
        my $sth = $dbh->prepare("
            UPDATE koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements
                SET $column = '".$value."'
            WHERE biblionumber = $biblionumber
        ");
        $sth->execute();
        if ($sth->err) {
            my @cc = caller(0);
            die $cc[3]."():> ".$sth->errstr;
        }
    }
}

1;
