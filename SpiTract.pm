package WWW::SpiTract;

use 5.006;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our $VERSION = '0.01';

use WWW::SpiTract::Spider;
use WWW::SpiTract::Extract;

use Data::Dumper;
use HTML::Tree;
use POSIX qw/tmpnam/;
use URI;
use Digest::MD5 qw/md5/;
use File::Slurp;

# ----------------------------------------------------------------------
# Building an html-tree
# ----------------------------------------------------------------------
use IO::String;
sub bldTree{
    $_[0] || return;
    my($immedf) = POSIX::tmpnam();
    $SIG{INT} = sub{ unlink $immedf ; exit;};
    my $h = HTML::TreeBuilder->new_from_content($_[0]);
    $h->ignore_unknown(0);
    open TREEDUMP, ">$immedf" or die;
    $h->dump(*TREEDUMP);
    close TREEDUMP;
    $h = $h->delete(); # nuke it!

    my $t = read_file( $immedf );
    unlink $immedf;
    $SIG{INT} ='DEFAULT';
$t
}

# ----------------------------------------------------------------------
# Generating description template
# ----------------------------------------------------------------------
sub genDescTmpl{
    <<TMPL;
{
  HANDL 
   =>
  {
        NAME => "",
        NEXT => [
            'http://foo/' => 'http://bar',
        ],
        POLICY =>[
            'http://bar'  => [
			      ["NODE1" => "0.0.0" ],
			      ],
        ],
        METHOD => 'POST',
        QHANDL => 'http://foo/query',
        PARAM => [
                  ['param1', ''],
                  ],
        KEY => 'query',
  },
};
TMPL
}


#                                                               << OO >>
# ----------------------------------------------------------------------
# constructor
# ----------------------------------------------------------------------

sub new{
    my($pkg, $desc, $settings)= @_;
    my($justhaveit);
    bless{
	DESC       => $desc,
	SPOOL      => undef,       # URL queue
	BEEF       => undef,       # desired info
	JUSTHAVEIT => $justhaveit, # stores checksums of urls that are retrieved
	HTTP_PROXY => $settings->{HTTP_PROXY},
	TIMEOUT    => $settings->{TIMEOUT},
    },$pkg
}

# ----------------------------------------------------------------------
# Feeding urls
# ----------------------------------------------------------------------

sub feed{
    my($pkg, $arg, $level)=@_;
    my($method, $url)= map { $arg->{$_} } qw/METHOD URL/;
    push @{$pkg->{SPOOL}}, [ $method, $url ];
}

# ----------------------------------------------------------------------
# Frontend
# ----------------------------------------------------------------------

sub spitract{
    my($pkg) = shift;
    $pkg->{QUERY} = shift;
    $pkg->feed({
	       URL         => $pkg->{DESC}->{QHANDL},
	       METHOD      => $pkg->{DESC}->{METHOD},
	       PARAM       => $pkg->{DESC}->{PARAM},
	       QUERY       => [ $pkg->{DESC}->{KEY} , $pkg->{QUERY} ],
	       });

    do{	$pkg->_spitract() } while @{$pkg->{SPOOL}};

    $pkg->{BEEF};
}

# ----------------------------------------------------------------------
# Backend
# ----------------------------------------------------------------------

sub _spitract{
    my($pkg)=shift;
    my($food) = shift @{$pkg->{SPOOL}};
    my($method, $url) = @$food;

    my $thisurl =
      WWW::SpiTract::Spider::queryURL(
				      {
					  URL         => $url,
					  METHOD      => $method,
					  PARAM       => $pkg->{DESC}->{PARAM},
					  QUERY       => [
							  $pkg->{DESC}->{KEY},
							  $pkg->{QUERY}
							  ],
				      });
    my $cud = md5($thisurl);  # current url digest ; md5 used to avoid duplication
    return if $pkg->{JUSTHAVEIT}->{$cud};
    $pkg->{JUSTHAVEIT}->{$cud} = 1;

    $url = URI->new_abs($url, $thisurl)->as_string unless $url =~ /^http:/;

    my ($content) = WWW::SpiTract::Spider->new({
	URL         => $url,
	METHOD      => $method,
	PARAM       => $pkg->{DESC}->{PARAM},
	QUERY       => [ $pkg->{DESC}->{KEY} , $pkg->{QUERY} ],
	HTTP_PROXY  => $pkg->{HTTP_PROXY},
	TIMEOUT     => $pkg->{TIMEOUT},
    })->content;

    return unless $content;

    my $k = WWW::SpiTract::Extract->new({
	TEXT    => bldTree($content),
	DESC    => $pkg->{DESC},
	THISURL => $thisurl,
    })->extract;

    foreach (@$k){
	print Dumper $_;
	if(exists $_->{DTLURL}){
	    if($_->{DTLURL} =~ /^http:/){
		push @{$pkg->{SPOOL}},['PLAIN', $_->{DTLURL} ];
	    }
	    else{
		$_->{DTLURL} = URI->new_abs($_->{DTLURL}, $thisurl)->as_string;
		push @{$pkg->{SPOOL}},['PLAIN', $_->{DTLURL} ];
	    }
	}
	push @{$pkg->{BEEF}}, $_;
    }
}


1;
__END__

=head1 NAME

WWW::SpiTract - WWW robot plus text analyzer

=head1 SYNOPSIS

  use WWW::SpiTract;
  use Data::Dumper;
  $spitract = WWW::SpiTract->new($desc,
				 {
				     TIMEOUT => 1,
				     HTTP_PROXY => 'http://fooproxy:2345/',
				 });
  print Dumper $spitract->spitract( $query );


=head1 DESCRIPTION

WWW::SpiTract combines the power of a www robot and a text analyzer. It can fetch a series of web pages with some attributes in common, for example, a product catalogue. Users write down a description file and WWW::SpiTract can do fetching and extract desired data. This can be applied to do price comparison or meta search, for instance.

=head1 METHODS

=head2 new

  $s = WWW::SpiTract->new($desc,
			  {
			      TIMEOUT => 1,
			      HTTP_PROXY => 'http://fooproxy:2345/',
			  });

TIMEOUT is 10 seconds by default

=head2 spitract

  $s->spitract() returns an anonymous array of retrieved data.

You may use Data::Dumper to see it. 

=head1 OTHER TOOLS

=head2 WWW::SpiTract::bldTree(htmltext)

builds a html-tree text. See also HTML::TreeBuilder

=head2 WWW::SpiTract::genDescTmpl

automatically generates a description template.

=head1 DESC FILE TUTORIAL

=head2 OVERVIEW

Currently, this module uses native Perl's anonymous array and hash for users to write down site descriptions. Let's see an example. Suppose the product query url of "foobar technology" is B<http://foo.bar/query.pl?encoding=UTF8&product=blahblahblah>
 {
   SITE  =>
   {
    NAME => "foobar tech.",
    NEXT => [
     'query.pl' => 'detail.pl',
    ],
    POLICY => [
      'http://foo.bar/detail.pl'
      =>
      [
        ["PRODUCT" => "0.1.1.0.0.5.1" ],
        ["PRICE"   => "0.1.1.0.0.5.1.0" ],
       ],
      ],
    METHOD => 'GET',
    QHANDL => 'http://foo.bar/query.pl',
    PARAM => [
     ['encoding', 'UTF8'],
    ],
    KEY => 'product',
   }
 };

=head2 SITE

Key to the settings.

=head2 NAME

The name of the site.

=head2 NEXT

NEXT is an anonymous array containing pairs of (this pattern => next pattern). If the current url matches /this pattern/, then text is searched for urls that match /next pattern/ and the urls are queued for next retrieval.

=head2 POLICY

POLICY is an anonymous array containing pairs of (this pattern => node settings). If the current url matches /this pattern/, then data at the given node will be retrieved.
Format of a slice is like this:

  [ NODE_NAME =>
    STARTING_NODE,
    [ VARIABLE INDEX ],
    [ STEPSIZE ],
    [ ENDING ],
    [ sub{FILTER here} ]
   ]

NODE_NAME is the output key to the node data. VARIABLE INDEX is an array of integers, denoting the index numbers of individual digits in starting node at which STARTING_NODE evolves. Using Cartesian product, nodes expand one STEPSIZE one time until digits at VARIABLE INDEX are all identical to those given in ENDING.

FILTER is left to users to write callback functions handling retrieved data.

Except NODE_NAME and STARTING_NODE, all of them are optional.

See also t/extract.pl

=over 1

=item * POLICY example

[ "PRODUCT" =>
  "0.0.0.0",
  [ 1, 3 ],
  [ 1, 2 ],
  [ 3, 4 ],
  sub { local $_ = shift; s/\s//g; $_ }
]

Data at 0.0.0.0, 0.0.0.2, 0.0.0.4, 0.1.0.0, 0.1.0.2, 0.1.0.4, 0.2.0.0, 0.2.0.2, 0.2.0.4, 0.3.0.0, 0.3.0.2, and 0.3.0.4 will be extracted with spaces eliminated.

=back


=head2 METHOD

Request method: GET, POST, or PLAIN.

=head2 QHANDL

"Query Handler", Url of the query script.

=head2 PARAM

Constant script parameters without user's queries.

=head2 KEY

Key to user's query strings, e.g. product names

=head1 AUTHOR

xern <xern@cpan.org>

=head1 LICENSE

Released under The Artistic License.

=head1 SEE ALSO

B<WWW::SpiTract::Spider>, B<WWW::SpiTract::Extract>, B<LWP>, B<WWW::Search>

=cut
