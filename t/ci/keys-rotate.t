#!/usr/bin/env perl
# ex:ts=8 sw=4:
#
# Guards for the key workflow and its two composite actions
#
# WEB-ACTIONS-13. The reusable workflow runs beside a private key,
# and nothing under .github/ or actions/ runs outside a runner. The
# test therefore reads each file as text and holds the order of the
# steps, and each guard, exactly as the workflow writes them.
#
# The order is the design: an install runs before the token
# (WEB-ACTIONS-5), the new key reaches the idle slot before the
# commit, and the slot variable moves after the site serves the
# bytes (WEB-ACTIONS-7). A reordered step passes every YAML parse
# and fails here.

use v5.36;
use Test::More;
use FindBin qw($RealBin);

my $root     = "$RealBin/../..";
my $workflow = "$root/.github/workflows/keys-rotate.yml";
my $slot     = "$root/actions/keys-slot/action.yml";
my $store    = "$root/actions/keys-store/action.yml";

# _slurp($path):
#	Whole file as text, or undef with a failed assertion.
sub _slurp ($path)
{
	open my $fh, '<', $path or do {
		fail("$path is readable");
		return;
	};
	local $/ = undef;
	my $content = <$fh>;
	close $fh;

	return $content;
}

ok( -f $workflow, 'the reusable workflow stands' );
ok( -f $slot,     'the keys-slot action stands' );
ok( -f $store,    'the keys-store action stands' );

my $text = _slurp($workflow) // q{};
my @lines = split /\n/, $text;

# WEB-ACTIONS-13. The whole order, as one list. A step that moves,
# a step that goes, and a step that arrives each fail this one
# assertion, and the list below is the order that the rules fix.
subtest 'the workflow holds the order of the steps' => sub {
	my @steps = map { /^      - name: (.+)$/ ? $1 : () } @lines;

	my @order = (
		'Refuse an input that this workflow cannot serve',
		'Checkout',
		'Install the dependencies',
		'Confirm that fuguweb runs',
		'Mint an installation token',
		'Report the reach of the token',
		'Read the slot of the purpose',
		'Read the root slot',
		'Name the bound keys of a root step',
		'Run the rotation step',
		'Mask the new private key',
		'Store the new private key',
		'Commit the key directory',
		'Publish the site',
		'Confirm the published site serves what this run wrote',
		'Move the slot variable',
		'Remove the working directory',
	);

	is_deeply( \@steps, \@order, 'every step stands in its place' )
	    or diag( "the workflow names:\n" . join "\n", @steps );
};

# WEB-ACTIONS-13. Each guard, as text. A guard that goes takes its
# message with it, and a run then reaches a credential, a verb or a
# secret write with an input that no step refused.
subtest 'the workflow holds each guard' => sub {
	my @guards = (
		'the step $STEP is not mint, import or promote',
		'the purpose $word is no lower-case word',
		'the secret prefix $PREFIX is no upper-case word',
		'the owner $OWNER is no organization name',
		'the directory $DIRECTORY leaves the tree',
		'an import needs the public key file',
		'a $STEP reads no public key file',
		'a step of $PURPOSE binds no subordinate purpose',
		'keys-rotate: cannot read the slot of $purpose',
		'keys-rotate: no slot of $purpose holds $stem',
		'the root slot holds no key, and this',
		'the idle slot of $PURPOSE holds no',
		'the active slot of $PURPOSE holds',
		'no key to promote',
	);

	for my $guard (@guards) {
		ok( index( $text, $guard ) >= 0, "the workflow refuses: $guard" );
	}

	# The guard step comes first, so a bad input reaches no
	# credential at all.
	my ($first) = $text =~ /^      - name: (.+)$/m;
	is( $first, 'Refuse an input that this workflow cannot serve',
		'the guard step runs before every other step' );
};

# _scripts($text):
#	The body of every run: block, as one list of lines. A run
#	holds its command on the same line, or in a block scalar over
#	the lines that follow it.
sub _scripts ($body)
{
	my @out;
	my @all = split /\n/, $body;
	for my $i ( 0 .. $#all ) {
		next unless $all[$i] =~ /^(\s+)run:(.*)$/;
		my ( $indent, $rest ) = ( length $1, $2 );

		# A one-line run holds the command after the key.
		if ( $rest !~ /^\s*[|>]/ ) {
			push @out, $rest;
			next;
		}

		for my $j ( $i + 1 .. $#all ) {
			last
			    if $all[$j] =~ /\S/
			    && $all[$j] =~ /^(\s*)/
			    && length($1) <= $indent;
			push @out, $all[$j];
		}
	}

	return @out;
}

# WEB-ACTIONS-4. Each secret reaches a step through the environment,
# and never through the script text. An expression in a script body
# becomes part of the command that the runner writes, so a value
# that holds a quotation mark or a semicolon becomes a command.
subtest 'no expression reaches a script body' => sub {
	for my $file ( $workflow, $slot, $store ) {
		my @bad = grep { /\$\{\{/ } _scripts( _slurp($file) // q{} );
		is( scalar @bad, 0, "$file writes no expression into a script" )
		    or diag( join "\n", @bad );
	}

	# The one read that an input forms. The secrets context takes
	# no name from an input, and its JSON form does.
	like(
		$text,
		qr/\QfromJSON(toJSON(secrets))[format('{0}_APP_ID'\E/,
		'the App id comes out of the JSON form of the context'
	);
	like(
		$text,
		qr/\Qsecrets: \E\$\{\{ \QtoJSON(secrets)\E \}\}/,
		'each slot read takes the context as JSON'
	);
};

# WEB-ACTIONS-11. The job runs beside a private key, so every action
# of another owner carries a commit. An action of this repository
# carries a branch: the workflow and the action land in one commit,
# and a commit cannot name itself.
subtest 'every action of another owner carries a commit pin' => sub {
	my $pinned = 0;
	my %own;

	for my $i ( 0 .. $#lines ) {
		next unless $lines[$i] =~ /^\s+uses:\s*(\S+)\s*$/;
		my $ref = $1;

		if ( $ref =~ m{^FuguBSD/FuguWeb/actions/([\w-]+)\@main$} ) {
			$own{$1}++;
			next;
		}

		unlike( $ref, qr{^FuguBSD/},
			      "line @{[$i + 1]} names no other action of"
			    . ' this repository' );

		$pinned++;
		like( $ref, qr/\@[0-9a-f]{40}$/,
			"line @{[$i + 1]} pins $ref to a commit" );
	}

	# WEB-ACTIONS-6 reads two slots, and WEB-ACTIONS-7 writes the
	# secret and moves the variable in two steps of its own.
	is( $own{'keys-slot'}, 2, 'the workflow reads two slots' );
	is( $own{'keys-store'}, 2, 'the workflow stores and moves apart' );
	is( $pinned, 2, 'the workflow uses two actions of another owner' );
};

# WEB-ACTIONS-9. The workflow holds no organization name, no domain
# and no repository list. Each one is an input, so a second
# publisher calls the same file.
subtest 'the workflow names no publisher' => sub {
	unlike( $text, qr{https?://}, 'the workflow holds no URL' );

	my @names = grep { /FuguBSD/ && !/^\s+uses:/ } @lines;
	is( scalar @names, 0, 'FuguBSD appears in a uses: line alone' )
	    or diag( join "\n", @names );

	for my $input (qw(org url owner visibility secret_prefix)) {
		like( $text, qr/\Qinputs.$input\E/,
			"the workflow reads $input from an input" );
	}
};

# WEB-ACTIONS-14. The environment binds here, from the input. The
# permissions, the concurrency group and secrets: inherit stay in
# the caller, which holds the trigger that needs them.
subtest 'the callee job takes the environment alone' => sub {
	like( $text, qr/^    environment: \$\{\{ inputs\.environment \}\}$/m,
		'the job binds the environment from the input' );

	for my $key (qw(permissions concurrency)) {
		unlike( $text, qr/^\s{0,4}$key:/m,
			"the workflow declares no $key" );
	}
};

# WEB-ACTIONS-12. Every private key of the run lives in one
# directory, and the last step removes it whatever the outcome.
subtest 'the run leaves no private key behind' => sub {
	# The step is the last one of the list above, and it runs on
	# every outcome, so a failed step leaves no key file.
	like(
		$text,
		qr/^      - name: Remove the working directory\n\s+if: always\(\)\n\s+env:\n\s+WORK:[^\n]+\n\s+run: rm -rf "\$WORK"$/m,
		'the last step removes the work directory on every outcome'
	);
};

# WEB-ACTIONS-3. The two actions hold the slots, so a caller that
# writes its own workflow composes them instead of this one.
subtest 'the actions hold the slots' => sub {
	my $slot_text  = _slurp($slot)  // q{};
	my $store_text = _slurp($store) // q{};

	like( $slot_text, qr/^  using: composite$/m,
		'keys-slot is a composite action' );
	like( $store_text, qr/^  using: composite$/m,
		'keys-store is a composite action' );

	for my $output (qw(active idle)) {
		like( $slot_text, qr/^  $output:$/m,
			"keys-slot answers the $output slot letter" );
	}

	# WEB-ACTIONS-7. One call stores the key, and a second call
	# moves the variable, so the two never run as one step.
	like( $store_text, qr/^\s+if \[ "\$MOVE" = yes \]; then$/m,
		'keys-store moves the variable only when the caller asks' );
	like( $store_text, qr/^\s+if \[ -n "\$FILE" \]; then$/m,
		'keys-store writes a secret only when the caller names a file' );
};

done_testing();
