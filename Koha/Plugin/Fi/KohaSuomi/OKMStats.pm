package Koha::Plugin::Fi::KohaSuomi::OKMStats;

## It's good practice to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use CGI qw ( -utf8 );

use Koha::Plugins;
use Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM;

## Here we set our plugin version
our $VERSION = "2.0.3";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'OKM Stats Plugin',
    author          => 'Emmi Takkinen',
    date_authored   => '2021-09-01',
    date_updated    => "2021-09-06",
    minimum_version => '21.05.02.003',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin implements every available feature '
      . 'of the plugin system and is meant '
      . 'to be documentation and a starting point for writing your own plugins!',
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

## The existance of a 'report' subroutine means the plugin is capable
## of running a report. This example report can output a list of patrons
## either as HTML or as a CSV file. Technically, you could put all your code
## in the report method, but that would be a really poor way to write code
## for all but the simplest reports

sub report {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    $self->report_view();
}

## If your tool is complicated enough to needs it's own setting/configuration
## you will want to add a 'configure' method to your plugin like so.
## Here I am throwing all the logic into the 'configure' method, but it could
## be split up like the 'report' method is.

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {

        my $template = $self->get_template({ file => 'configure.tt' });

        ## Grab the values we already have for our settings, if any exist
        $template->param(
            okm_syspref => $self->retrieve_data('okm_syspref'),
        );

        $self->output_html( $template->output() );
    }
    else {
        $self->store_data(
            {
                okm_syspref => $cgi->param('okm_syspref'),
                last_configured_by => C4::Context->userenv->{'number'},
            }
        );
        $self->go_home();
    }
}

## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
sub install() {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;
    my $table = $self->get_qualified_table_name('biblio_data_elements');
    $dbh->do("
        CREATE TABLE IF NOT EXISTS $table (
        `id` int(12) NOT NULL AUTO_INCREMENT,
        `biblioitemnumber` int(11) NOT NULL,
        `last_mod_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        `deleted` tinyint(1) DEFAULT NULL,
        `deleted_on` timestamp DEFAULT NULL,
        `primary_language` varchar(3) DEFAULT NULL,
        `languages` varchar(40) DEFAULT NULL,
        `fiction` tinyint(1) DEFAULT NULL,
        `musical` tinyint(1) DEFAULT NULL,
        `celia` tinyint(1) DEFAULT NULL,
        `itemtype` varchar(10) DEFAULT NULL,
        `serial` tinyint(1) DEFAULT NULL,
        `encoding_level` varchar(1) DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `bibitnoidx` (`biblioitemnumber`),
        KEY `last_mod_time` (`last_mod_time`),
        KEY `encoding_level` (`encoding_level`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
    ");

    $table = $self->get_qualified_table_name('okm_statistics');

    $dbh->do("
        CREATE TABLE IF NOT EXISTS $table (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `startdate` datetime DEFAULT NULL,
        `enddate` datetime DEFAULT NULL,
        `individualbranches` text,
        `okm_serialized` longtext,
        `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
    ");

    $table = $self->get_qualified_table_name('okm_statistics_logs');

    $dbh->do("
        CREATE TABLE IF NOT EXISTS $table (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `entry` text NOT NULL,
        PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
    ");

    return 1;
}

## This is the 'upgrade' method. It will be triggered when a newer version of a
## plugin is installed over an existing older version of a plugin
sub upgrade {
    my ( $self, $args ) = @_;

    my $dt = dt_from_string();
    $self->store_data( { last_upgraded => $dt->ymd('-') . ' ' . $dt->hms(':') } );

    return 1;
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;

    my $biblio_data_elements = $self->get_qualified_table_name('biblio_data_elements');
    $dbh->do("DROP TABLE $biblio_data_elements");

    my $okm_statistics = $self->get_qualified_table_name('okm_statistics');
    $dbh->do("DROP TABLE $okm_statistics");

    my $okm_statistics_logs = $self->get_qualified_table_name('okm_statistics_logs');
    $dbh->do("DROP TABLE $okm_statistics_logs");

    return 1;
}

sub report_view {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $okm_reports = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM->RetrieveAll();
    my $okm_statisticsId = $cgi->param('okm_statisticsId');

    if ( $cgi->param('show') ) {
        my $okm = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM::Retrieve( $okm_statisticsId );
        my $errors;
        unless ($okm) {
            push @$errors, "Couldn't retrieve the given okm_report with koha.okm_statistics.id = $okm_statisticsId";
        }
        $self->okm_statistics_home($errors, $okm_statisticsId, $okm);
        
        #TODO, this feature doesn't work ATM and better rules for cross-examining statistics is needed. $template->param('okm_report_errors' => join('<br/>',@$errors)) if scalar(@$errors) > 0;
    } elsif ( $cgi->param('export') ) {
        my $input = new CGI;
        my $format = $cgi->param('format');
        my $okm = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM::Retrieve( $okm_statisticsId );
        my $error = _export( $format, $okm, $okm_statisticsId );
        $self->okm_statistics_home($error, $okm_statisticsId, $okm);
    } elsif ( $cgi->param('delete') ) {
        my $err = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM::Delete($okm_statisticsId);
        
        $self->okm_statistics_home($err);

    } elsif ( $cgi->param('deleteLogs') ) {
        Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKMLogs::deleteLogs();
        $self->okm_statistics_home();
    } else {
        my $errors;
        
        #Create an OKM-object just to see if the configurations are intact.
        eval {
            my $okmTest = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM->new(undef, '2015', undef, undef, undef);
        }; if ($@) {
            $errors = $@;
            #$errors = "Something went wrong. Please contact system administration.";
        }
     
        $self->okm_statistics_home($errors);
    }

}

sub okm_statistics_home {
    my ($self, $errors, $okm_statisticsId, $okm) = @_;

    my $template = $self->get_template({ file => 'okm_reports.tt' });
    my $okm_reports = Koha::Plugin::Fi::KohaSuomi::OKMStats::Modules::OPLIB::OKM->RetrieveAll();
    
    
    $template->param(
        okm_reports => $okm_reports,
    );
    $template->param(okm => $okm) if $okm;    
    $template->param(okm_errors => $errors);
    $template->param(okm_statisticsId => $okm_statisticsId);

    $self->output_html( $template->output() );
}

sub _export {
    my ($format, $okm, $okm_statisticsId) = @_;
    my $input = new CGI;
    my ($csv, $errors);
    unless ($okm) {
        return 'reportUnavailable';
    }

    my ( $type, $content );
    if ($format eq 'tab') {
        $type = 'application/octet-stream';
        $content = $okm->asCsv("\t");
    }
    elsif ($format eq 'csv') {
        $type = 'application/csv';
        $content = $okm->asCsv(',');
    }
    elsif ( $format eq 'ods' ) {
        $type = 'application/vnd.oasis.opendocument.spreadsheet';
        $content = $okm->asOds();
    }

    print $input->header(
        -type => $type,
        -attachment=>"OKM_statistics_$okm_statisticsId.$format"
    );
    print $content;

    exit;
}

1;
