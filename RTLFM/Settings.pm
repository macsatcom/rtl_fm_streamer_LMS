# Plugins/RTLFM/Settings.pm
package Plugins::RTLFM::Settings;
use strict;
use warnings;

use Slim::Web::Pages;
use Slim::Web::Request;
use Slim::Utils::Prefs;
use Slim::Utils::Log;

# Prefer JSON::XS, fall back to JSON::PP
eval {
    require JSON::XS;
    JSON::XS->import(qw(encode_json decode_json));
    1;
} or do {
    require JSON::PP;
    JSON::PP->import(qw(encode_json decode_json));
};

my $prefs;

sub init {
    my ($class, $p) = @_;
    $prefs = $p;

    # Register a simple JSON settings endpoint at /plugins/RTLFM/settings
    Slim::Web::Pages->addPageFunction('plugins/RTLFM/settings', \&settingsPage);
}

sub settingsPage {
    my ($client, $params, $callback) = @_;

    my $method = Slim::Web::Request->getRequestMethod();

    if ($method eq 'POST') {
        my $data = Slim::Web::Request->getRequestBody();

        my $obj = eval { decode_json($data || '{}') } || {};

        $prefs->set('server_ip', $obj->{server_ip} || '');
        $prefs->set('server_port', $obj->{server_port} || 2346);
        $prefs->set('stations', encode_json($obj->{stations} || []));

        # Return JSON response indicating success
        my $out = encode_json({ success => JSON::XS::true });
        $callback->($out);
        return;
    }

    # GET: return current settings as JSON
    my $out = {
        server_ip => $prefs->get('server_ip') || '',
        server_port => $prefs->get('server_port') || 2346,
        stations => eval { decode_json($prefs->get('stations') || '[]') } || [],
    };

    $callback->(encode_json($out));
}

1;
