package PML::Tokenizer;

use v5.10;

use strict;
use warnings;
use boolean;

use Moo;
use PML::Tokenizer::Token;

my $debug = false;

has 'pml'	 	 => ( is => 'rw', required => true, trigger => \&_tokenize ); # Raw PML input
has 'tokens' 	 => ( is => 'rw' ); # Array

# Parsing
has 'state'		 => ( is => 'rw' );
has 'content'	 => ( is => 'rw' );
has 'head_level' => ( is => 'rw' );

has 'link_data'	 => ( is => 'rw' );
has 'image_data' => ( is => 'rw' );

# Matching contexts
has 'matching_context' => ( is => 'rw' );

use Readonly;
Readonly my $MAX_HEAD_LEVEL => 6;

Readonly my $C_EM	=> '/';

# -----------------------------------------------------------------------------

sub _tokenize {
	my ($self) = @_;

	# Initial state is 'data'
	$self->state('data');

	$self->matching_context({});

	# Tokens initially empty
	$self->tokens([]);

	my @chars = split //, $self->pml;
	
	# Parse until we run out of data
	while (@chars) {
		my $c = shift @chars;

		D("Read [$c] - Current state [",$self->state,"]");
		
		my $state = $self->state;

		if ($state eq 'data') {

			if ($c eq '#') {
				# Possible header
				$self->_move_to_state('p_heading');
				$self->head_level(0); # Reset header level counter
			}
			elsif ($c eq $C_EM) { $self->_move_to_state('p_emphasis')  }
			elsif ($c eq '*') { $self->_move_to_state('p_strong')  	 }
			elsif ($c eq '_') { $self->_move_to_state('p_underline') }
			elsif ($c eq '"') { $self->_move_to_state('p_quote') 	 }
			elsif ($c eq "\n"){ $self->_move_to_state('p_newpara')	 }
			elsif ($c eq '[') { $self->_move_to_state('p_s_link')    }	
			elsif ($c eq '{') { $self->_move_to_state('p_s_image')	 }			
			elsif ($c eq ' ') {
				# If we're in a block, output it, otherwise skip it
				if ($self->_is_block_open || $self->_is_head_block_open) {
					$self->_new_char_token(' ');
				}
			}
			elsif ($c eq "\n"){ unshift @chars, ' ' }
			else {								 				
				if (!$self->_is_block_open && !$self->_is_head_block_open) {
					$self->_new_token('S_BLOCK','[[S_BLOCK]]');
				}
				$self->_new_char_token( $c );
			}

		}
		elsif ($state eq 'p_strong') 	{ $self->_emit_control_token( $c, 'STRONG', 	'[[STRONG]]', '*', \@chars ) }
		elsif ($state eq 'p_underline') { $self->_emit_control_token( $c, 'UNDERLINE',  '[[UNDER]]',  '_', \@chars ) }	
		elsif ($state eq 'p_emphasis')  { $self->_emit_control_token( $c, 'EMPHASIS', 	'[[EMPH]]',   $C_EM, \@chars ) }
		elsif ($state eq 'p_quote')  	{ $self->_emit_control_token( $c, 'QUOTE', 		'[[QUOTE]]',  '"', \@chars ) }		
		elsif ($state eq 'p_s_image')	{

			if ($c eq '{') {
				$self->_move_to_state('image_data');
				$self->image_data('');				
			}
			else {
				$self->_new_char_token( '{' );
				unshift @chars, $c;				
			}
			next;

		}
		elsif ($state eq 'image_data') {

			if ($c eq '}') {
				# Definitely starting an image now, so if there's an open block, close it.
				$self->_close_block_if_open;
				$self->_move_to_state( 'p_e_image' );
			}
			else {
				$self->image_data( $self->image_data.$c );
			}
			next;

		}
		elsif ($state eq 'p_e_image') {

			if ($c eq '}') {
				# Finish the image token
				D(" -> Write image token [",$self->image_data,"]");
				$self->_new_token( 'IMAGE', $self->image_data);
				$self->_move_to_state('data');	
				next;
			}
			else {
				# Otherwise still in the image data so add
				# the char to the current image data and move
				# to consume the next char.
				$self->image_data( $self->image_data.$c );
				unshift @chars, $c;
				next;
			}

		}
		elsif ($state eq 'p_s_link') {

			if ($c eq '[') {
				$self->_move_to_state('link_data');
				$self->link_data('');
			}
			else {
				$self->_new_char_token( '[' );
				unshift @chars, $c;
			}
			next;

		}		
		elsif ($state eq 'link_data') {

			if ( $c eq ']' ) {
				$self->_move_to_state( 'p_e_link' );
				next;
			}
			else {
				# Whilst in 'link_data' state, treat anything other than
				# link closing tags as char data into the temporary link data.				
				$self->link_data( $self->link_data.$c );
				next;
			}

		}
		elsif ($state eq 'p_e_link') {

			if ($c eq ']') {
				# Finish the link token
				D(" -> Write link token [",$self->link_data,"]");
				$self->_new_token( 'LINK', $self->link_data);
				$self->_move_to_state('data');	
			}
			else {
				# Otherwise still in the link data so add
				# the char to the current link data and move
				# to consume the next char.
				$self->link_data( $self->link_data.$c );
				unshift @chars, $c;
			}
			
		}
		elsif ($state eq 'p_newpara') {

			if ($c eq "\n") {
				$self->_close_block_if_open;				
			}
			else {
				# If there was just a single one then output a break token
				# and push the next char back to the queue.
				#$self->_new_char_token( "\n" );
				$self->_new_token( 'BREAK', '' );
				unshift @chars, $c;
			}
			$self->_move_to_state('data');

		}
		elsif ($state eq 'p_heading') {

			if ($c eq '#') {
				# Started a header already, so increment the
				# level that we've reached
				$self->head_level($self->head_level+1);

				# If we've reached the max level then error
				if ($self->head_level>$MAX_HEAD_LEVEL) {
					die "Bad HEADER sequence - too long";
				}
			}			
			else {
				# If we've at least reached header level 1 then we output a header token.
				# Otherwise assume it's just a hash character so output that and what we
				# just read as character tokens.
				$self->_finalise_heading;				
				unshift @chars, $c;
				$self->_move_to_state('data');
			}

		}
		next; # Not needed, just makes flow more explicit :p
	}

	# Fix heading at end of input.
	# Reached end of input so deal with any open header tokens.
	if ($self->state eq 'p_heading') {
		$self->_finalise_heading;
	}

	# Make sure that BLOCKs are closed, so if the last token wasn't a block,
	# let's emit one.
	if ($self->_is_block_open) {
		$self->_new_token( 'E_BLOCK', '' );
	}

	return;
}

# -----------------------------------------------------------------------------

sub _emit_control_token {
	my ($self, $char, $type, $content, $plain, $chars_ar) = @_;

	if ($char eq $plain) {
		# If there isn't a block open, then we need to open on		
		$self->_new_token( 'S_BLOCK', '[[S_BLOCK]]') unless $self->_is_block_open;		

		# If the token isn't already listed as Start or End then
		# determine which we need.
		if ($type =~ /^(E|S)_/) {
			$self->_new_token( $type, $content );
		}
		else {
			$self->_new_token( ($self->_is_open($type) ?'E':'S')."_$type", $content );		
		}
	}
	else {
		# If not a match then output the potential
		# that we had as a plain char token.
		$self->_new_token( 'CHAR', $plain );
		unshift @$chars_ar, $char;				
	}
	$self->_move_to_state('data');
}

# -----------------------------------------------------------------------------

sub _close_block_if_open {	 
	$_[0]->_new_token( 'E_BLOCK', '[[E_BLOCK]]' ) if $_[0]->_is_block_open;	
	return;
}

# -----------------------------------------------------------------------------

sub _is_open {
	my ($self, $type) = @_;
	return ($_[0]->matching_context->{$type}||0)%2;
}

sub _is_block_open {	
	return ($_[0]->matching_context->{BLOCK}||0)%2		
}

sub _is_head_block_open {	
	return ($_[0]->matching_context->{HEAD1}||0)%2
		|| ($_[0]->matching_context->{HEAD2}||0)%2
		|| ($_[0]->matching_context->{HEAD3}||0)%2
		|| ($_[0]->matching_context->{HEAD4}||0)%2
		|| ($_[0]->matching_context->{HEAD5}||0)%2
		|| ($_[0]->matching_context->{HEAD6}||0)%2;
}

# -----------------------------------------------------------------------------

sub _finalise_heading {
	my ($self) = @_;
	if ((my $level = $self->head_level) > 0) {
		
		my $open_or_close = $self->_is_open("HEAD$level") ?'E':'S';
		
		# If we've currently got a block open, then we need to close it.
		if ($self->_is_block_open && $open_or_close eq 'S') {
			$self->_new_token( 'E_BLOCK', '[[E_BLOCK]]');			
		}

		# Output the appropriate level header token
		$self->_new_token( $open_or_close."_HEAD$level", "[[H$level]]" );		
	}
	else {
		# Treat as plain # and whatever we just read
		$self->_new_token( 'S_BLOCK','[[S_BLOCK]]') unless ($self->_is_block_open);
		$self->_new_token( 'CHAR', '#' );
	}
	return;
}

# -----------------------------------------------------------------------------

sub _new_char_token {
	my ($self, $content) = @_;
	$self->_new_token('CHAR',$content);
	return;
}

# -----------------------------------------------------------------------------

sub _new_token {
	my ($self, $type, $content) = @_;
	
	D(" -> Emit [$type] token [$content]");
	
	# Need to update the matching counts so for that we need the specific
	# type (without any leading S_ or E_)
	(my $specific_type = $type) =~ s/^(S|E)_//;	
	if ($specific_type ne 'CHAR') {
		$self->matching_context->{$specific_type}++;
		D(" -> Update matching for '$specific_type'");
	}


	push @{$self->tokens},
		 PML::Tokenizer::Token->new( type => $type, content => $content );
	return;
}

# -----------------------------------------------------------------------------

sub _move_to_state {
	my ($self, $state) = @_;
	D(" -> Move to state [$state]");
	$self->state($state);
	return;
}

# -----------------------------------------------------------------------------

sub get_next_token {
	my ($self) = @_;

	if ( @{$self->tokens}>0 ) {
		return shift @{$self->tokens};
	}
	else {
		return 0;
	}
}

# -----------------------------------------------------------------------------

sub D {warn @_ if $debug}

1;

=pod

=head1 TITLE

PML::Tokenizer

=head1 SYNOPSIS

  use PML::Tokenizer;

  my $tokenizer = PML::Tokenizer->new( pml => $pml_string );

  while( my $token = $tokenizer->get_next_token ) {
	
	# Do something with the token

  }


=head1 DESCRIPTION

Simple tokenizer for PML tokens.

=head1 METHODS

=head2 get_next_token

Return the next token or C<0> if there are no more tokens read.

=cut

