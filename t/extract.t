# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 3 };
use WWW::SpiTract;

ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

$desc = {
    test  =>
    {
        NAME => "test",
        NEXT => [ ],
        POLICY =>[
		  'test\.foobar'
		  =>
		  [
		   [
		    "LINGUA" => "0.1.0.0.0",
		    [ 3 ], [ 1 ], [ 5 ],
		    sub{ local $_=shift; s/\s//g; $_ }
		   ],
		   ],
		  ],
        METHOD => 'PLAIN',
    },

};


{
    local $/;
    $s = <DATA>;
}

use Data::Dumper;
$s = WWW::SpiTract::bldTree($s);

ok( 'title', WWW::SpiTract::Extract::lookup($s , '0.0.0')->{tag} );

$e = WWW::SpiTract::Extract->new({
             TEXT    => $s,
             DESC    => $desc->{test},
             THISURL => 'http://test.foobar.com/',
         });
print Dumper $e->extract;
ok('spanish', $e->extract->[3]->{LINGUA});


__DATA__
<html>
<head>
<title> This is a test. </title>
</head>
<body>
<table>
<tr> <td> latin
<tr> <td> italian
<tr> <td> french
<tr> <td> spanish
<tr> <td> romanian
<tr> <td> portuguese
</table>
</body>
</html>
