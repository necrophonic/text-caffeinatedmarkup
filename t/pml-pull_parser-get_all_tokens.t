#!/usr/bin/env perl

use strict;

use Test::More;
use Test::Exception;

use Readonly;
Readonly my $CLASS => 'PML::PullParser';

use_ok $CLASS;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($OFF);

my $parser;

	subtest "Simple parse" => sub {
		$parser = $CLASS->new(pml => 'Simple **PML** to parse');
		my @tokens = ();
		lives_ok {@tokens = $parser->get_all_tokens()}, 'Parse without error';	
	};

	test_simple_markup();
	test_link_markup();


done_testing();

# ==============================================================================

sub get_tokens_string {
	my ($tokens_r) = @_;
	my @types;
	for (@$tokens_r) { push @types, $_->{type} }
	return join ',',@types;
}

# ------------------------------------------------------------------------------

sub test_simple_markup {

	subtest "Test simple markup" => sub {

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

		subtest "Underline" => sub {
			$parser = $CLASS->new(pml => 'With __underline__ in middle');
			my @tokens = $parser->get_all_tokens;
			is( get_tokens_string(\@tokens), 'STRING,UNDERLINE,STRING,UNDERLINE,STRING', 'Underline in string' );

			$parser = $CLASS->new(pml => '__underline__ at start');
			my @tokens = $parser->get_all_tokens;
			is( get_tokens_string(\@tokens), 'UNDERLINE,STRING,UNDERLINE,STRING', 'Underline at start' );

			$parser = $CLASS->new(pml => 'At the end is __underline__');
			my @tokens = $parser->get_all_tokens;
			is( get_tokens_string(\@tokens), 'STRING,UNDERLINE,STRING,UNDERLINE', 'Underline at end' );
		};

		subtest "Del" => sub {
			$parser = $CLASS->new(pml => 'With --del-- in middle');
			my @tokens = $parser->get_all_tokens;
			is( get_tokens_string(\@tokens), 'STRING,DEL,STRING,DEL,STRING', 'Del in string' );

			$parser = $CLASS->new(pml => '--del-- at start');
			my @tokens = $parser->get_all_tokens;
			is( get_tokens_string(\@tokens), 'DEL,STRING,DEL,STRING', 'Del at start' );

			$parser = $CLASS->new(pml => 'At the end is --del--');
			my @tokens = $parser->get_all_tokens;
			is( get_tokens_string(\@tokens), 'STRING,DEL,STRING,DEL', 'Del at end' );
		};
	};
	return;
}

# ------------------------------------------------------------------------------

sub test_link_markup {
	subtest "Test link markup" => sub {

		subtest "Simple link" => sub {
			$parser = $CLASS->new(pml => "Go here [[http://www.google.com]] it's cool");
			my @tokens = $parser->get_all_tokens;
			is(get_tokens_string(\@tokens),'STRING,LINK,STRING','Link with just href');
			is($tokens[1]->{href}, 'http://www.google.com', 'Href set ok');
			is($tokens[1]->{text}, '', 'Text is null');
		};

		subtest "Simple link with text" => sub {
			$parser = $CLASS->new(pml => "Go here [[http://www.google.com|Google]] it's cool");
			my @tokens = $parser->get_all_tokens;
			is(get_tokens_string(\@tokens),'STRING,LINK,STRING','Link with text');
			is($tokens[1]->{href}, 'http://www.google.com', 'Href set ok');
			is($tokens[1]->{text}, 'Google', 'Text set ok');
		};

	};
	return;
}

# ------------------------------------------------------------------------------

