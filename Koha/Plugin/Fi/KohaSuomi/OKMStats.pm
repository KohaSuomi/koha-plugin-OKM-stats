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
our $VERSION = "2.0.7";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Raportointityökalu',
    author          => 'Emmi Takkinen, Lari Strand',
    date_authored   => '2021-09-01',
    date_updated    => "2022-09-07",
    minimum_version => '21.05.02.003',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'OKM-tilastot ja erilaisia raportteja/työkaluja/tilastoja kuntien ja kirjastojen tarpeisiin ',
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
        `deleted_on` timestamp NULL DEFAULT NULL,
        `primary_language` varchar(3) DEFAULT NULL,
        `languages` varchar(40) DEFAULT NULL,
        `fiction` tinyint(1) DEFAULT NULL,
        `cn_class` varchar(10) DEFAULT NULL,
        `musical` tinyint(1) DEFAULT NULL,
        `celia` tinyint(1) DEFAULT NULL,
        `itemtype` varchar(10) DEFAULT NULL,
        `host_record` int(11) DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `bibitnoidx` (`biblioitemnumber`),
        KEY `last_mod_time` (`last_mod_time`)
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

    return 1;
}

sub report {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $template = $self->get_template({ file => 'index.tt' });
    
    my $dbh = C4::Context->dbh;
    
    my $words = $dbh->selectcol_arrayref( "SELECT branchcode FROM branches" );
    
     $template->param(
        branches => ($words)
    );

    
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

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_dir = $self->mbf_dir();
    return JSON::Validator->new->schema($spec_dir . "/openapi.json")->schema->{data};
    #my $spec_str = $self->mbf_read('openapi.json');
    #my $spec     = decode_json($spec_str);

    #return $spec;
}

sub api_namespace {
    my ( $self ) = @_;
    
    return 'kohasuomi';
}

1;
