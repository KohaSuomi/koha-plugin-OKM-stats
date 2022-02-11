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

sub isBiblioitemFiction {
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

sub isSerial {
    my ($self, $itemtype) = @_;
    my $col = 'serial';

    my $okm = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM->new(undef, '2015', undef, undef, undef);
    my $itemtypes = $okm->{conf}->{itemTypeToStatisticalCategory};
    my @itemtypes = grep { %$itemtypes{$_} eq 'Serials' } keys %$itemtypes;
    my $val = grep /^$itemtype$/, @itemtypes;

    ($self->{dbi}) ? $self->{$col} = $val : $self->set({$col => $val});
}

sub setItemtype {
    my ($self, $itemtype) = @_;
    my $col = 'itemtype';

    ($self->{dbi}) ? $self->{$col} = $itemtype : $self->set({$col => $itemtype});
}

=head setLanguages

    $bde->setLanguage($record);

Sets the languages- and primary_language-columns.
Defaults to "OTH" if fields 008 or 041 do not contain acceptable
string (3 character long, contains only alphabets).

@PARAM1, MARC::Record

=cut

sub setLanguages {
    my ($self, $record) = @_;
    my $f008 = $record->field('008');
    my $primaryLanguage = 'OTH';

    if( substr($f008->data(), 35, 3) && ( substr($f008->data(), 35, 3) =~ /(.*[a-zA-Z]){3}/ )) {
        $primaryLanguage = substr($f008->data(), 35, 3);
    } elsif ( $record->subfield('041', 'a') && ( $record->subfield('041', 'a') =~ /(.*[a-zA-Z]){3}/ ) ) {
        $primaryLanguage = $record->subfield('041', 'a');
    } elsif ( $record->subfield('041', 'd') && ( $record->subfield('041', 'd') =~ /(.*[a-zA-Z]){3}/ ) ) {
        $primaryLanguage = $record->subfield('041', 'd');
    }

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
    ($self->{dbi}) ? $self->{'primary_language'} = $primaryLanguage : $self->set({'primary_language' => $primaryLanguage});
}

sub setDeleted {
    my ($self, $deleted, $timestamp) = @_;
    my $col = 'deleted';
    my $col2 = 'deleted_on';

    ($self->{dbi}) ? $self->{$col} = $deleted : $self->set({$col => $deleted});
    if($deleted){
        ($self->{dbi}) ? $self->{$col2} = $timestamp : $self->set({$col2 => $timestamp});
    }
}

sub setEncodingLevel {
    my ($self, $record) = @_;
    my $col = 'encoding_level';
    my $val = '';

    my $l = $record->leader();
    $val = substr($l,17,1); #17 - Encoding level

    ($self->{dbi}) ? $self->{$col} = $val : $self->set({$col => $val});
}


=head PERFORMANCE IMPROVEMENT TESTS USING DBI

    THIS MODULE IS SUPER SLOW, LOOKING TO SPEED IT USING plain DBI

=cut

sub DBI_new {
    my ($class, $bdeHash, $biblioitemnumber) = @_;
    unless ($bdeHash && ref $bdeHash eq 'HASH') {
        $bdeHash = {};
    }
    bless($bdeHash, $class);
    $bdeHash->{dbi} = 1;
    return $bdeHash;
}

sub DBI_getBiblioDataElement {
    my ($biblioitemnumber) = @_;
    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare("
        SELECT * FROM koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements
        WHERE biblioitemnumber = ?;
    ");
    $sth->execute( $biblioitemnumber );
    if ($sth->err) {
        my @cc = caller(0);
        die $cc[3]."():> ".$sth->errstr;
    }
    my $bde = $sth->fetchrow_hashref();
    return Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::BiblioDataElement->DBI_new($bde, $biblioitemnumber);
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
            musical = ?,
            celia = ?,
            itemtype = ?,
            serial = ?,
            encoding_level = ?
        WHERE biblioitemnumber = ?;
    ");
    $sth->execute( $bde->{deleted}, $bde->{deleted_on}, $bde->{primary_language}, $bde->{languages}, $bde->{fiction}, $bde->{musical}, $bde->{celia}, $bde->{itemtype}, $bde->{serial}, $bde->{encoding_level}, $bde->{biblioitemnumber} );
    if ($sth->err) {
        my @cc = caller(0);
        die $cc[3]."():> ".$sth->errstr;
    }
}

sub DBI_insertBiblioDataElement {
    my ($bde, $biblioitemnumber) = @_;
    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare("
        INSERT INTO koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements
            (biblioitemnumber, deleted, deleted_on, primary_language, languages, fiction, musical, celia, itemtype, serial, encoding_level)
            VALUES
            (?               , ?      , ?         , ?               , ?        , ?      , ?      , ?    , ?       , ?      , ?);
    ");
    $sth->execute( $biblioitemnumber, $bde->{deleted}, $bde->{deleted_on}, $bde->{primary_language}, $bde->{languages}, $bde->{fiction}, $bde->{musical}, $bde->{celia}, $bde->{itemtype}, $bde->{serial}, $bde->{encoding_level} );
    if ($sth->err) {
        my @cc = caller(0);
        die $cc[3]."():> ".$sth->errstr;
    }
}

1;
