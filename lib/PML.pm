package PML;

use v5.10;

our $VERSION = '0.6';

use strict;
use warnings;
use boolean;

use HTML::Escape;
use PML::Tokenizer;

# ------------------------------------------------------------------------------

sub _type_to_tag {
	my ($type) = @_;	
	$type ||= '';
	my $map = {
		HEAD1		=> 'h1',
		HEAD2		=> 'h2',
		HEAD3		=> 'h3',
		HEAD4		=> 'h4',
		HEAD5		=> 'h5',
		HEAD6		=> 'h6',
		STRONG		=> 'strong',
		EMPHASIS	=> 'em',
		UNDERLINE	=> 'u',
		BLOCK		=> 'p',
		QUOTE		=> 'blockquote',
		LINK		=> 'a',
		BREAK		=> 'br',
		ROW_BLOCK	=> 'div',
		COLUMN		=> 'div',
	};
	if (exists $map->{$type}) { return $map->{$type}}
	die "No mapping for type '$type'";
}

# ------------------------------------------------------------------------------

sub markdown {
	my ($pml) = @_;
	my $html = '';

	# Clean the PML before we start as we don't allow 
	# interpretable HTML.
	# $pml = HTML::Escape::escape_html($pml);	

	# # Fix "quot"s
	# $pml =~ s/\&quot;/\"/g;

	
	# $pml =~ s/^ *//g; # Leading spaces
	# $pml =~ s/ *$//g; # Trailing spaces

	# $pml =~ s/\&gt;\&gt;/>>/g;
	# $pml =~ s/\&lt;\&lt;/<</g;

	my $tokenizer = PML::Tokenizer->new( pml => $pml );

	# Initialise stack for nested tag completion
	# Stack is upside down so we know the "head" is always
	# at position zero.
	my @stack = ();

	while(my $token = $tokenizer->get_next_token) {

		my $type = $token->type;		

		if 	  ($type eq 'CHAR') { $html .= $token->content }
		elsif ($type eq 'S_ROW_BLOCK') {

			my @classes = ('clearfix');
			my $class 	= '';

			foreach my $modifier (split /,/, $token->content) {
				if ($modifier =~ /^C(\d)/) { push @classes, 'col-'.$1 }
			}
						
			$class = ' class="'.join(' ',@classes).'"' if @classes;
			$html .= qq|<div$class>|;

		}		
		elsif ($type eq 'E_ROW_BLOCK') { $html .= q|</div>| }
		elsif ($type eq 'S_COLUMN')	   { $html .= q|<div>|  }
		elsif ($type eq 'E_COLUMN')	   { $html .= q|</div>| }
		elsif ($type eq 'LINK') {

			my $href   = $token->url;
			my $text   = $token->text;
			my $target = $href=~/^http/?' target="_new"':'';			

			$html .= qq|<a href="$href"$target>$text</a>|;

		}
		elsif ($type eq 'IMAGE') {
			
			my $src = $token->src;
			
			my $width  = $token->width  ? ' width="' .$token->width .'px"' : '';
			my $height = $token->height ? ' height="'.$token->height.'px"' : '';

			my $class = '';
			if 	  ($token->align eq '<<') { $class  = q| class="pulled-left"|  }
			elsif ($token->align eq '>>') { $class  = q| class="pulled-right"| }

			$html .= qq|<img$class src="$src"$height$width>|;

		}
		else {			

			my ($start_end, $item) = $type =~ /^(S|E)_(.+)$/;
			$start_end ||= '';

			if ($start_end eq 'S') {
				$html .= _start_type($item);
				unshift @stack, $item
			}
			elsif ($start_end eq 'E') {				
				if ($stack[0] ne $item) {
					die "Unbalanced tags!"
				}
				else {
					$html .= _end_type($item);
					shift @stack; # If ok then pull off the head
				}
			}
			else {
				# Single tag
				$html .= '<'._type_to_tag($type).'>';
			}
		}
	}

	$html =~ s/ +/ /g; # Multiple spaces

	return "$html\n";
}

# ------------------------------------------------------------------------------

sub _start_type { return '<' ._type_to_tag($_[0]).'>' }
sub _end_type   { return '</'._type_to_tag($_[0]).'>' }

# ------------------------------------------------------------------------------

1;

=pod

=head1 TITLE

PML - Panda Markdown Language to HTML converter

=head1 SYNOPSIS

  use PML;

  my $pml = 'The //quick// brown __fox__ jumped over the lazy **dog**';

  my $html = PML::markdown( $pml );

=head1 DESCRIPTION

Convert text written in PML into HTML.

=cut
