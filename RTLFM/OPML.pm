# Plugins/RTLFM/OPML.pm
package Plugins::RTLFM::OPML;
use strict;
use warnings;

use Slim::Utils::Prefs;
use Slim::Utils::Log;
use Slim::Control::Request;

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

    # Register a simple dispatch so the UI can call /plugins/rtlfm/browse
    Slim::Control::Request::addDispatch(
        ['plugins', 'rtlfm', 'browse'],
        \&browseHandler
    );
}

sub browseHandler {
    my $request = shift;
    my $cli = $request->client;

    my $stations_json = $prefs->get('stations') || '[]';
    my $stations = eval { decode_json($stations_json) } || [];

    my @items;
    foreach my $s (@$stations) {
        my $name = $s->{name} || 'Unknown';
        my $freq_mhz = $s->{freq} || 100;
        my $freq_hz = int($freq_mhz * 1_000_000 + 0.5);

        my $ip = $prefs->get('server_ip') || '127.0.0.1';
        my $port = $prefs->get('server_port') || 2346;

        my $streamUrl = "http://$ip:$port/$freq_hz/1";

        push @items, {
            title => "$name ($freq_mhz MHz)",
            url => $streamUrl,
            type => 'track',
            image => '',
        };
    }

    # Provide the items back to the requester.
    $request->addResult('items', \@items);
}

1;
