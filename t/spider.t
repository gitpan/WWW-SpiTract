# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 2 };
use WWW::SpiTract;

ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

for(qw/news.google.com news.bbc.co.uk www.cnn.com www.nytimes.com/){
    $s = new WWW::SpiTract::Spider({
	URL         => "http://$_",
	METHOD      => 'PLAIN',
	TIMEOUT     => 30,
    });
    $text .= $s->content;
    last if $text;
}

ok( ($text ? 1 : 0), 1);
