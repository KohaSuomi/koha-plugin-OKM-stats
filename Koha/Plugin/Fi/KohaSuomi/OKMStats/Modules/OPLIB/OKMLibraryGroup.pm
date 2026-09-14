package Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKMLibraryGroup;

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

use Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKMGroupStatistics;

sub new {
    my ($class, $categoryGroupCode, $branches) = @_;

    croak '$branches parameter is not a HASH of {branchcode => 1, ...}!' unless (ref $branches eq 'HASH');

    my $self = {};
    bless($self, $class);

    $self->addStatistics( Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKMGroupStatistics->new() );
    my $stats = $self->getStatistics();
    $stats->{library} = $categoryGroupCode;
    $self->{library} = $categoryGroupCode;

    foreach my $branchcode (sort keys %$branches) {
        $self->addBranch($branchcode);
    }

    return $self;
}

sub addBranch {
    my ($self, $branchcode) = @_;

    $self->{branches}->{$branchcode} = {};
}
sub getBranchesWithKeys {
    my $self = shift;
    my @keys = keys %{$self->{branches}};
    return ($self->{branches}, \@keys);
}

sub addStatistics {
    my ($self, $groupStatistics) = @_;
    $self->{statistics} = $groupStatistics;
}
sub getStatistics {
    my $self = shift;
    return $self->{statistics};
}

1;