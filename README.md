# OKM Statistics Plugin

This plugin is for updating biblio_data_elements table and generating OKM statistics.

# Downloading

From the [release page](https://github.com/bywatersolutions/koha-plugin-kitchen-sink/releases) you can download the relevant *.kpz file

# Installing

Koha's Plugin System allows for you to add additional tools and reports to Koha that are specific to your library. Plugins are installed by uploading KPZ ( Koha Plugin Zip ) packages. A KPZ file is just a zip file containing the perl files, template files, and any other files necessary to make the plugin work.

The plugin system needs to be turned on by a system administrator.

To set up the Koha plugin system you must first make some changes to your install.

* Change `<enable_plugins>0<enable_plugins>` to `<enable_plugins>1</enable_plugins>` in your koha-conf.xml file
* Confirm that the path to `<pluginsdir>` exists, is correct, and is writable by the web server
* Restart your webserver

On the Tools page you will see the Tools Plugins and on the Reports page you will see the Reports Plugins.

# Configure

OKM configuration and statistical type mappings are set from plugins configuration.
# Cronjobs

This plugin contains two cronjobs, update_biblio_data_elements.pl and generateOKMAnnualStatistics.pl.
Cronjobs should be executed daily, preferably at night to prevent interfere with Koha's normal use.

Example:

```
PERL5LIB=/path/to/koha
KOHA_CONF=/path/to/koha-conf.xml
PATH_TO_PLUGIN=/path/to/plugin

00 05 * * * $PATH_TO_PLUGIN/Koha/Plugin/Fi/KohaSuomi/OKMStats/cronjobs/update_biblio_data_elements.pl --verbose 2
00 35 * * * $PATH_TO_PLUGIN/Koha/Plugin/Fi/KohaSuomi/OKMStats/cronjobs/generateOKMAnnualStatistics.pl --timeperiod 'lastyear' -r -v
```
