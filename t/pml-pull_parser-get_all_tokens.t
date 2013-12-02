#!/usr/bin/env perl

use strict;

use Test::More;
use Test::Exception;

use Readonly;
Readonly my $CLASS => 'PML::PullParser';

use_ok $CLASS;

my $parser;

subtest "Simple parse" => sub {
	$parser = $CLASS->new(pml => 'Simple **PML** to parse');
	my @tokens = ();
	lives_ok {@tokens = $parser->get_all_tokens()}, 'Parse without error';
	
	
};


subtest "Strong" => sub {
	$parser = $CLASS->new(pml => 'Simple **PML** to parse');
	my @tokens = $parser->get_all_tokens;
	is( get_tokens_string(\@tokens), 'STRING,STRONG,STRING,STRONG,STRING', 'Strong in string' );

	$parser = $CLASS->new(pml => '**Strong** at start');
	my @tokens = $parser->get_all_tokens;
	is( get_tokens_string(\@tokens), 'STRONG,STRING,STRONG,STRING', 'Strong at start' );

	$parser = $CLASS->new(pml => 'At the end is **Strong**');
	my @tokens = $parser->get_all_tokens;
	is( get_tokens_string(\@tokens), 'STRING,STRONG,STRING,STRONG', 'Strong at end' );
};


subtest "Emphasis" => sub {
	$parser = $CLASS->new(pml => 'With //emphasis// in middle');
	my @tokens = $parser->get_all_tokens;
	is( get_tokens_string(\@tokens), 'STRING,EMPHASIS,STRING,EMPHASIS,STRING', 'Emphasis in string' );

	$parser = $CLASS->new(pml => '//Emphasis// at start');
	my @tokens = $parser->get_all_tokens;
	is( get_tokens_string(\@tokens), 'EMPHASIS,STRING,EMPHASIS,STRING', 'Emphasis at start' );

	$parser = $CLASS->new(pml => 'At the end is //emphasis//');
	my @tokens = $parser->get_all_tokens;
	is( get_tokens_string(\@tokens), 'STRING,EMPHASIS,STRING,EMPHASIS', 'Emphasis at end' );
};


done_testing();

# ======

sub get_tokens_string {
	my ($tokens_r) = @_;
	my @types;
	for (@$tokens_r) {
		push @types, $_->{type};
	}
	return join ',',@types;
}