package Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKMGroupStatistics;

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
use Carp;

use Koha::AuthorisedValues;
use Koha::Libraries;

use JSON;

sub new {
    my ($class) = @_;

    my $self = {};
    bless($self, $class);

    my @itemtypes = Koha::AuthorisedValues->search( { category => 'MTYPE' } )->as_list;
    my %itemtypes = ();
    for my $av ( @itemtypes ) {
        $itemtypes{$av->authorised_value} = 0;
    }

    my %data_hash = (
        total => 0,
        books_total => 0,
        books_finnish => 0,
        books_swedish => 0,
        books_sami => 0,
        books_other_lang => 0,
        books_fiction_adult => 0,
        books_fiction_juvenile => 0,
        books_fact_adult => 0,
        books_fact_juvenile => 0,
        sheet_music_score => 0,
        musical_recordings => 0,
        other_recordings => 0,
        videos => 0,
        celia => 0,
        other => 0
    );

    $self->{library} = 0;
    $self->{collection_by_homebranch} = { %data_hash };
    $self->{collection_by_homebranch}->{itemtypes} = { %itemtypes };
    $self->{collection_by_holdingbranch} = { %data_hash };
    $self->{collection_by_holdingbranch}->{itemtypes} = { %itemtypes };
    $self->{issues} = { %data_hash };
    $self->{issues}->{itemtypes} = { %itemtypes };
    $self->{deleted} = { %data_hash };
    $self->{deleted}->{itemtypes} = { %itemtypes };
    $self->{acquisitions} = { %data_hash };
    $self->{acquisitions}->{itemtypes} = { %itemtypes };
    $self->{acquisitions}->{expenditures} = 0;
    $self->{acquisitions}->{expenditures_books} = 0;
    $self->{active_borrowers} = 0;
    $self->{celia_borrowers} = 0;

    return $self;
}


sub asHtmlHeader {
    my ($self) = @_;

    my @sb;
    push @sb, '<thead><tr>';
    for (my $i=0 ; $i<@{$self->{printOrder}} ; $i++) {
        my $key = $self->{printOrder}->[$i];
        push @sb, "<td>$key</td>";
    }
    push @sb, '</tr></thead>';

    return join("\n", @sb);
}
sub asHtml {
    my ($self) = @_;

    my @sb;
    push @sb, '<tr>';
    for (my $i=0 ; $i<@{$self->{printOrder}} ; $i++) {
        my $key = $self->{printOrder}->[$i];
        push @sb, '<td>'.$self->{$key}.'</td>';
    }
    push @sb, '</tr>';

    return join("\n", @sb);
}

sub asCsvHeader {
    my ($self, $separator) = @_;

    my @sb;
    for (my $i=0 ; $i<@{$self->{printOrder}} ; $i++) {
        my $key = $self->{printOrder}->[$i];
        push @sb, "\"$key\"";
    }
    return join($separator, @sb);
}
sub asCsv {
    my ($self, $separator) = @_;

    my @sb;
    for (my $i=0 ; $i<@{$self->{printOrder}} ; $i++) {
        my $key = $self->{printOrder}->[$i];
        push @sb, '"'.$self->{$key}.'"';
    }

    return join($separator, @sb);
}

=head getPrintOrder

    $stats->getPrintOrder();

@RETURNS Array of Strings, all the statistical keys/columnsHeaders in the desired order.
=cut
sub getPrintOrder {
    my ($self) = @_;

    return $self->{printOrder};
}

=head getPrintOrderElements

    $stats->getPrintOrderElements();

Gets all the calculated statistical elements in the defined printOrder.
@RETURNS Pointer to an Array of Statistical Floats.
=cut
sub getPrintOrderElements {
    my ($self) = @_;

    my @sb;
    for (my $i=0 ; $i<@{$self->{printOrder}} ; $i++) {
        my $key = $self->{printOrder}->[$i];
        push @sb, $self->{$key};
    }

    return \@sb;
}

1;