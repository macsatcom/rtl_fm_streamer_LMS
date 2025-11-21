# Plugins/RTLFM/Plugin.pm
package Plugins::RTLFM::Plugin;
use strict;
use warnings;

use Slim::Utils::PluginManager ();
use Slim::Utils::Prefs;
use Slim::Utils::Log;

use Plugins::RTLFM::OPML;
use Plugins::RTLFM::Settings;

my $prefs;

sub initPlugin {
    my ($class, $client, $args) = @_;

    $prefs = preferences('plugin.RTLFM');

    # Initialize OPML/browse provider and settings page
    Plugins::RTLFM::OPML->init($prefs);
    Plugins::RTLFM::Settings->init($prefs);

    Slim::Utils::Log->info("RTLFM plugin initialized");
}

1;
