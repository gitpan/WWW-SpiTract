package WWW::SpiTract::Extract;

use 5.006;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our $VERSION = '0.01';

use HTML::Tree;
use Data::Dumper;
use URI;

# ----------------------------------------------------------------------
# WWW::SpiTract::Extract::lookup(parsed_text, nodeID)
# ----------------------------------------------------------------------

sub lookup($$) {
    my ($t, $nid) = @_;
    my $r;
    $r->{tag}='';
    $r->{text}='';
    return $r unless $t && $nid;
    $r->{tag} = $1 if $t =~ /<(.+?)>\s+\@$nid\n/;
    $r->{text} = $1 if $t =~ /\@$nid\n\s+"(.+?)"\n/;
$r
}



# ----------------------------------------------------------------------
# constructor
# ----------------------------------------------------------------------

sub new {
    my($pkg, $arg) = @_;
    my($obj) = {
	DESC        => $arg->{DESC},      # configuraion
	TEXT        => $arg->{TEXT},      # parsed html file
	THISURL     => $arg->{THISURL},
	DEBUG       => $arg->{DEBUG},
    };
bless $obj, $pkg
}

# ----------------------------------------------------------------------
# Extraction
# ----------------------------------------------------------------------

sub extract($) {
    my ($pkg)   = shift;
    my ($tt)    = $pkg->{TEXT};       # tree text
    my ($tu)    = $pkg->{THISURL};    # this url
    my ($desc)  = $pkg->{DESC};
    my (@retarr)= qw//;
    my ($output, $c, $corrupt);
    my (%output);
    my ($type, $urlpatt, $nextpatt);

    ### extract links ###
    for(my $i=0; $i<@{$desc->{NEXT}}; $i+=2){
	$_ = $desc->{NEXT}->[$i];
	if($_ && $tu =~ /$_/){
	    my $p = $desc->{NEXT}->[$i+1];
	    while($tt =~ /$p/g){
		next unless $1;
		undef $output;
		$c = $1;
		$c = URI->new_abs($c, $tu)->as_string if($c !~ /^http:/);
		$output->{DTLURL} = $c;
		push @retarr, $output;
	    }
	}
    }
    ### Node expansion ###
    my ($nodes, @linevect, $filter);
    for(my $i=0; $i<@{$desc->{POLICY}}; $i+=2){
	local $_ = $desc->{POLICY}->[$i];
	if($_ && $tu =~ /$_/){
	    ($nodes, $filter) = loadDESC($desc->{POLICY}->[$i+1]);
	}
    }
    @linevect = split /\n/o, $pkg->{TEXT};


    foreach my $n (@$nodes){
        undef $output;
        foreach my $k (keys %$n){
	    next unless $k;
            $c=q//;
	    $c = get(\@linevect, $n->{$k});
            $output->{$k} = $c;
	    if( defined $filter->{$k} ){
		$output->{$k} = $filter->{$k}->($output->{$k});
	    }
        }
	push @retarr, $output;
    }
\@retarr
}

# ----------------------------------------------------------------------
# Cartesian Expansion
# ----------------------------------------------------------------------

sub cart($$$$){
    my ($s, $i, $p, $e) = @_; # (starting, changing index, stepsize, ending)
    return unless @$i == @$p;
    my $c = 0;
    my (@r);
    push @r, join q/./, @$s;
  EXPANSION:
    while(1){
	last unless @$e;
        $s->[$i->[-1]] += $p->[-1];
        for(my $j = $#$i; $j>0; $j--){
            if($s->[$i->[$j]] == $e->[$j]){
                $s->[$i->[$j]] = 0;
                $s->[$i->[$j-1]] += $p->[$i->[$j-1]];
            }
        }

        push @r, join q/./, @$s;

	my $escape = 1;
	for(my $k = 0; $k<@$i; $k++){
	    undef $escape if($s->[$i->[$k]] != $e->[$k]);
	}
	last if $escape;
    }
\@r
}

# ----------------------------------------------------------------------
# Loading desc
# ----------------------------------------------------------------------

sub loadDESC {
    my($h) = shift;
    my($sidx, $sdif, $LBD, $UBD, $th, $ft);
    for my$C (@$h){
	unless( defined $C->[2] && defined $C->[3] && defined $C->[4] ){
	    $th->[0]->{$C->[0]} = $C->[1];
	    next;
	}
	$sidx = $C->[2], $sdif = $C->[3], $UBD = $C->[4];
	$LBD=[ split /\./o, $C->[1] ];

	my($IV)=cart($LBD, $sidx, $sdif, $UBD);
	my $cnt = 0;
	for( @$IV){
	    $th->[$cnt++]->{$C->[0]} = $_;
	    if( defined $C->[5]){
		$ft->{$C->[0]} = $C->[5];
	    }
	}
    }
($th, $ft)
}


# ----------------------------------------------------------------------
# Retrieving text at some node
# ----------------------------------------------------------------------

sub get{
    my$linevect = shift;
    my$node = shift;
    my$cont;
    for my$i(0..$#$linevect){
        if($linevect->[$i]=~m[$node$]){ #(.*)?$]){
            my($j) = $i+1;
            while ($linevect->[$j] && 
		   $linevect->[$j++]=~/^[\s\t]+"(.*)"$/ ){
		my($c) = $1;
                $cont .= $1;
            }
        }
    }

$cont
}


1;
__END__

=head1 NAME

WWW::SpiTract::Extract - Text Extraction Module

=head1 SYNOPSIS

  use WWW::SpiTract::Extract;
 
  $e = WWW::SpiTract::Extract->new({
      TEXT    => $t,                      # webpage text
      DESC    => $desc->{foo},            # site foo
      THISURL => 'http://bazz.buzz.org/', # url of TEXT
  });

  print Dumper $e->extract;

=head1 DESCRIPTION

WWW::SpiTract::Extract extracts data against a given description file.

=head1 METHODS

=head2 new

  $e = new ({
     TEXT    => 'string parsed by HTML::Tree',
     THISURL => 'URL of the text',
     DESC    => 'data description'
  });

=head2 extract

  $e->extract returns an array of hashes. You may use Data::Dumper to see it

=head1 STANDALONES

=head2 WWW::SpiTract::Extract::lookup(parsed_text, node_identifier)

WWW::SpiTract::Extract::lookup($t, "0.0.0");

It looks up the given text for the given node identifier, and returns an anonymous hash with entries "tag" and "text".

=head1 AUTHOR

xern <xern@cpan.org>

=head1 LICENSE

Released under The Artistic License.

=head1 SEE ALSO

B<WWW::SpiTract>, B<WWW::SpiTract::Spider>, B<HTML::TreeBuilder>

=cut

