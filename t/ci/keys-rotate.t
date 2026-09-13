#!/usr/bin/env perl
# ex:ts=8 sw=4:
#
# Guards for the key workflow and its two composite actions
#
# WEB-ACTIONS-13. The reusable workflow runs beside a private key,
# and no step of it runs outside a runner. The test therefore reads
# each file as text. It holds the order of the steps, and each guard,
# exactly as the file writes them.
#
# The awk program of the root step is the one exception. It reads a
# description and needs no runner, so the last subtest runs it over a
# fixture.
#
# The order is the design: an install runs before the token
# (WEB-ACTIONS-5), the new key reaches the idle slot before the
# commit, and the slot variable moves after the site serves the
# bytes (WEB-ACTIONS-7). A reordered step passes every YAML parse
# and fails here.

use v5.36;
use Test::More;
use File::Temp;
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

# _write($path, $content):
#	Write one file of a fixture, or die.
sub _write ( $path, $content )
{
	open my $fh, '>', $path or die "open $path: $!";
	print {$fh} $content;
	close $fh;

	return;
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
		'Read the slot of each subordinate purpose',
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
# secret write with an input that no step refused. The two actions
# hold guards of their own, because a caller composes them alone.
subtest 'the workflow and the two actions hold each guard' => sub {
	my %guards = (
		$workflow => [
			'the step $STEP is not mint, import or promote',
			'the purpose is empty',
			'the purpose $word is no lower-case word',
			'the secret prefix $PREFIX is no upper-case word',
			'the owner $OWNER is no organization name',
			'the directory $DIRECTORY leaves the tree',
			'the directory is empty',
			'an import needs the public key file',
			'a $STEP reads no public key file',
			'a promote reads no key type',
			'a step of $PURPOSE binds no subordinate purpose',
			'keys-rotate: the $role slot of $purpose holds',
			'no key, and the step binds $stem again',
			'the root slot holds no key, and this',
			'the idle slot of $PURPOSE holds no',
			'the active slot of $PURPOSE holds',
			'no key to promote',
			'keys-rotate: the commit wrote no file of',
			'keys-rotate: the site never served what this run',
		],
		$slot => [
			'keys-slot: the purpose list is empty',
			'keys-slot: cannot read the slot variable of'
			    . ' $purpose',
		],
		$store => [
			'keys-store: the slot letter is empty',
			'keys-store: $FILE holds no key',
			'keys-store: the visibility list holds a character',
			'keys-store: the visibility list opens with a dash',
		],
	);

	for my $file ( $workflow, $slot, $store ) {
		my $body = _slurp($file) // q{};
		for my $guard ( @{ $guards{$file} } ) {
			ok( index( $body, $guard ) >= 0,
				"$file refuses: $guard" );
		}
	}

	# The guard step comes first, so a bad input reaches no
	# credential at all.
	my ($first) = $text =~ /^      - name: (.+)$/m;
	is( $first, 'Refuse an input that this workflow cannot serve',
		'the guard step runs before every other step' );
};

# _bodies($text):
#	The body of each run: block, as one string for each block. A
#	body ends at the first line that reaches the indentation of
#	the run: key.
sub _bodies ($body)
{
	my @out;
	my @all = split /\n/, $body;
	for my $i ( 0 .. $#all ) {
		next unless $all[$i] =~ /^(\s+)run:\s*[|>]/;
		my $indent = length $1;

		my @block;
		for my $j ( $i + 1 .. $#all ) {
			last
			    if $all[$j] =~ /\S/
			    && $all[$j] =~ /^(\s*)/
			    && length($1) <= $indent;
			push @block, $all[$j];
		}
		push @out, join "\n", @block;
	}

	return @out;
}

# _scripts($text):
#	Every line of every run: body, as one list. A run holds its
#	command on the same line, or in a block scalar over the lines
#	that follow it.
sub _scripts ($body)
{
	my @out = map { split /\n/ } _bodies($body);

	# A one-line run holds the command after the key.
	for my $line ( split /\n/, $body ) {
		next unless $line =~ /^\s+run:(.*)$/;
		my $rest = $1;
		push @out, $rest if $rest !~ /^\s*[|>]/;
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

# A body that splits a value into words must run set -f first. A
# value that holds a glob character would otherwise name a file of
# the working directory, and the list would take what stands there.
subtest 'each body that splits a value runs set -f' => sub {
	for my $file ( $workflow, $slot, $store ) {
		my $found = 0;
		for my $body ( _bodies( _slurp($file) // q{} ) ) {
			next
			    unless $body =~ /^\s*for \w+ in \$\w/m
			    || $body =~ /\s\$scope\b/;

			$found++;
			like( $body, qr/^\s*set -f$/m,
				      "$file: a body that splits a value"
				    . ' runs set -f' );
		}

		ok( $found, "$file holds one such body at least" );
	}
};

# WEB-ACTIONS-11. The job runs beside a private key, so every action
# of another owner carries a commit. An action of this repository
# takes its pin in the commit after the merge, because a commit
# cannot name its own SHA, and spec/STATUS.md records that part as
# absent. This test therefore reads the name of each action of this
# repository, and it holds no reference of one.
subtest 'every action of another owner carries a commit pin' => sub {
	my $pinned = 0;
	my %own;

	for my $i ( 0 .. $#lines ) {
		next unless $lines[$i] =~ /^\s+uses:\s*(\S+)\s*$/;
		my $ref = $1;

		if ( $ref =~ m{^FuguBSD/FuguWeb/actions/([\w-]+)\@\S+$} ) {
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

	# The purpose of the step, the root, and the subordinate
	# purposes of a root step: three reads, and one action serves
	# each one. WEB-ACTIONS-7 writes the secret and moves the
	# variable in two steps of its own.
	is( $own{'keys-slot'}, 3, 'three steps of the workflow read a slot' );
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

	# WEB-ACTIONS-3. The action holds the whole slot read, so the
	# workflow holds no copy of it.
	unlike( $text, qr{actions/variables/},
		'the workflow reads no slot variable itself' );
	like( $slot_text, qr{actions/variables/},
		'keys-slot reads the slot variable' );

	# WEB-TRUST-7. One step answers whether this run writes each
	# binding again, and the verb step reads that one answer.
	like( $text, qr/^\s+BIND: \$\{\{ steps\.bind\.outputs\.bind \}\}$/m,
		'the verb step reads the binding answer of the step above' );

	# WEB-ACTIONS-7. One call stores the key, and a second call
	# moves the variable, so the two never run as one step.
	like( $store_text, qr/^\s+if \[ "\$MOVE" = yes \]; then$/m,
		'keys-store moves the variable only when the caller asks' );
	like( $store_text, qr/^\s+if \[ -n "\$FILE" \]; then$/m,
		'keys-store writes a secret only when the caller names a file' );
};

# _awk($text):
#	The awk program of the root step, as the runner passes it. An
#	awk program in single quotes holds no quotation mark of its
#	own, so the first one after it ends the program.
sub _awk ($body)
{
	return $body =~ /\bawk '\n(.+?)\n\s*' [.]fuguwebrc\)/s ? $1 : undef;
}

# WEB-ROTATE-4. The description carries the status of each key, and
# the root step reads it to name the bound keys. Fugu::Config takes a
# comment behind a value, and t/fuguweb/rotate.t holds a description
# that carries one. A read that missed it would drop the key, and the
# step would write no binding for it.
subtest 'the root step reads a status as Fugu::Config does' => sub {
	my $program = _awk($text);
	ok( $program, 'the root step holds one awk program' ) or return;

	my $dir = File::Temp->newdir;
	_write( "$dir/program.awk", "$program\n" );

	# Each shape of the grammar: a comment behind a value, a value
	# in quotation marks, a setting with no equals sign, a block
	# name without quotation marks, a block that names no status,
	# and a setting outside every block.
	_write( "$dir/description", <<~"RC" );
		keys "keys" {
		\torg = fugubsd
		}

		key "fugubsd-1-release" {
		\tstatus = current\t# the live key
		}

		key "fugubsd-2-release" {
		\tstatus = "next"
		}

		key fugubsd-1-root {
		\tstatus = retired
		}

		key "fugubsd-1-doc" {
		\tstatus current
		}

		key "fugubsd-3-release" {
		\tsince = 2026-01-01
		}

		status = ignored
		RC

	my $out = qx{awk -f "$dir/program.awk" "$dir/description" 2>&1};
	is_deeply(
		[ split /\n/, $out ],
		[
			"fugubsd-1-release\tcurrent",
			"fugubsd-2-release\tnext",
			"fugubsd-1-root\tretired",
			"fugubsd-1-doc\tcurrent",
		],
		'each key answers its status, and no comment joins one'
	) or diag($out);
};

done_testing();
