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
my $module   = "$root/lib/App/FuguWeb/CLI.pm";

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

# WEB-ACTIONS-5. The install step names the install root, and gives
# the module path and the command path of that root to each step
# that follows. cpanm with no root, and with no named root, installs
# where @INC does not reach. A run without these three lines leaves
# the fuguweb command on PATH and every module of it outside @INC,
# and the step after it fails with "Can't locate App/FuguWeb/CLI.pm
# in @INC".
subtest 'the install step names the install root' => sub {
	my ($step) = $text =~ m{
		^\ {6}-\ name:\ Install\ the\ dependencies\n
		(.+?)
		(?=^\ {6}-\ name:\ )
	}msx;
	ok( $step, 'the workflow holds the install step' ) or return;

	like( $step, qr/^\s+PERL_LOCAL_LIB_ROOT: \S/m,
		'the step names the install root' );
	like(
		$step,
		qr{^\s+echo "PERL5LIB=\$PERL_LOCAL_LIB_ROOT/lib/perl5"\s+>> "\$GITHUB_ENV"$}m,
		'it gives the module path of that root to each later step'
	);
	like(
		$step,
		qr{^\s+echo "\$PERL_LOCAL_LIB_ROOT/bin" >> "\$GITHUB_PATH"$}m,
		'it gives the command path of that root to each later step'
	);
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
			'a promote makes no key directory',
			'a step of $PURPOSE binds no subordinate purpose',
			'the url $URL opens with a dash',
			'the publish workflow $WORKFLOW opens with a dash',
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
			'keys-slot: the purpose $purpose is no',
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
# carries a commit, whoever owns it. An action of this repository
# takes the commit that added it, because a commit cannot name its
# own SHA.
subtest 'every action carries a commit pin' => sub {
	my $pinned = 0;
	my %own;

	for my $i ( 0 .. $#lines ) {
		next unless $lines[$i] =~ /^\s+uses:\s*(\S+)\s*$/;
		my $ref = $1;

		if ( $ref =~ m{^FuguBSD/FuguWeb/actions/([\w-]+)\@\S+$} ) {
			$own{$1}++;
			like( $ref, qr/\@[0-9a-f]{40}$/,
				"line @{[$i + 1]} pins $ref to a commit" );
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

	# WEB-ACTIONS-6. The condition names a root promote, and a
	# first root mint, which finds no root slot. Every other root
	# step binds nothing, and it reads no subordinate slot, so it
	# writes no private key of another purpose to the runner.
	my ($gate) = $text =~ m{
		^\ {6}-\ name:\ Read\ the\ slot\ of\ each\ subordinate\ purpose\n
		(.+?)
		^\ {8}uses:
	}msx;
	ok( $gate, 'the subordinate slot read holds a condition' );

	for my $part (
		q{inputs.purpose == 'root'},
		q{inputs.subordinate_purposes != ''},
		q{inputs.step == 'promote'},
		q{steps.slot.outputs.active == ''} )
	{
		like( $gate // q{}, qr/\Q$part\E/,
			"the subordinate slot read tests $part" );
	}

	# WEB-ACTIONS-7. One call stores the key, and a second call
	# moves the variable, so the two never run as one step.
	like( $store_text, qr/^\s+if \[ "\$MOVE" = yes \]; then$/m,
		'keys-store moves the variable only when the caller asks' );
	like( $store_text, qr/^\s+if \[ -n "\$FILE" \]; then$/m,
		'keys-store writes a secret only when the caller names a file' );
};

# _group($body, $pattern):
#	The text inside the first bracket pair behind $pattern. The
#	bracket is a parenthesis or a brace, and the count runs over
#	each one, so a nested table stands inside the answer.
sub _group ( $body, $pattern )
{
	return unless $body =~ /$pattern\s*([({])/g;

	my $open  = $1;
	my $close = $open eq '(' ? ')' : '}';
	my $from  = pos($body) - 1;

	my $depth = 0;
	for my $i ( $from .. length($body) - 1 ) {
		my $char = substr $body, $i, 1;
		$depth++ if $char eq $open;
		$depth-- if $char eq $close;

		return substr $body, $from + 1, $i - $from - 1 unless $depth;
	}

	return;
}

# _names($table):
#	Each option name of one Getopt::Long table. A name stands in
#	quotation marks before a fat comma. The specification of the
#	argument follows the name, and an alias stands behind a
#	vertical bar.
sub _names ($table)
{
	my @out;
	while ( $table =~ /'([^']+)'\s*=>/g ) {
		my $spec = $1;
		$spec =~ s/[=:!+].*\z//;
		push @out, split /\|/, $spec;
	}

	return @out;
}

# _declared($source, $verb):
#	Each option name that CLI.pm declares for one verb. The option
#	table of a verb names each shared table with a sigil. The read
#	follows every such name, and it answers the union.
sub _declared ( $source, $verb )
{
	my $entry   = _group( $source, "'\Q$verb\E'\\s*=>" ) // return;
	my $options = _group( $entry, 'options\s*=>' ) // return;

	my @names = _names($options);
	for my $table ( $options =~ /%(\w+)/g ) {
		push @names,
		    _names( _group( $source, "my\\s+%$table\\s*=" ) // q{} );
	}

	return @names;
}

# _arguments($body, @steps):
#	Each option that the verb step can pass, as one triple. The
#	triple holds the step word, the option name, and the input of
#	each condition that holds the line. A line inside a case
#	branch runs for one step, and a line outside every branch runs
#	for each step.
sub _arguments ( $body, @steps )
{
	my ( @out, @held, $branch );

	for my $line ( split /\n/, $body ) {
		next unless $line =~ /\S/;

		my ($space) = $line =~ /^(\s*)/;
		my $indent = length $space;
		pop @held while @held && $held[-1][0] >= $indent;

		if ( $line =~ /^\s*if \[ -n "\$(\w+)" \]; then$/ ) {
			push @held, [ $indent, $1 ];
			next;
		}

		if ( $line =~ /^\s*(\w+)\)$/ ) {
			$branch = $1;
			next;
		}

		$branch = undef if $line =~ /^\s*;;$/;
		next unless $line =~ /^\s*args\+?=\(/;

		my @taken      = $branch ? ($branch) : @steps;
		my @conditions = map { $_->[1] } @held;
		for my $name ( $line =~ /(?:\(|\s)--([a-z][\w-]*)/g ) {
			push @out, [ $_, $name, \@conditions ] for @taken;
		}
	}

	return @out;
}

# _refused($guard, $step, $input):
#	True when the guard step holds the condition of $step and
#	$input. The guard names a fault there, and it exits before the
#	verb runs. Such a step therefore reaches the verb with an
#	empty $input, and a line that the input holds adds no option.
sub _refused ( $guard, $step, $input )
{
	return index( $guard, qq{[ "\$STEP" = $step ] && [ -n "\$$input" ]} )
	    >= 0;
}

# WEB-ROTATE-1. The verb step builds one option list, and CLI.pm
# declares the options of each verb. A verb answers "Unknown option"
# and exit code 2 for an option that it does not declare, and the run
# then fails at the verb step. Each name here
# comes from one of the two files. A list of names in this file would
# go stale, and the two files hold the names already.
subtest 'the verb step passes an option that the verb declares' => sub {
	my $body = _step_body('Run the rotation step');
	my $guard =
	    _step_body('Refuse an input that this workflow cannot serve');
	ok( $body,  'the verb step holds one run body' )  or return;
	ok( $guard, 'the guard step holds one run body' ) or return;

	my $source = _slurp($module) // q{};
	my @steps  = $body =~ /^\s*(\w+)\)$/gm;
	ok( scalar @steps, 'the verb step names one step word at least' );

	my %declared;
	for my $step (@steps) {
		my @names = _declared( $source, "$step-key" );
		ok( scalar @names, "CLI.pm declares the options of $step-key" );
		$declared{$step} = { map { $_ => 1 } @names };
	}

	my @arguments = _arguments( $body, @steps );
	ok( scalar @arguments, 'the verb step passes one option at least' );

	for my $argument (@arguments) {
		my ( $step, $option, $conditions ) = @{$argument};

		# The guard step refuses a $step that names the input,
		# and the input holds this line, so no such step
		# reaches the line.
		my ($refused) =
		    grep { _refused( $guard, $step, $_ ) } @{$conditions};
		if ($refused) {
			pass( "the guard step refuses a $step that names"
			    . " \$$refused" );
			next;
		}

		ok( $declared{$step}{$option}, "$step-key declares --$option" );
	}
};

# WEB-ROTATE-21 and WEB-ROTATE-22. Every step writes one key
# directory, and the word selects it. A step that makes that
# directory states the intent, and a promote makes none. A workflow
# that named neither would fail on a site with two directories, or
# would publish a second root of trust in silence.
subtest 'the verb step names the key directory of every step' => sub {
	my $body = _step_body('Run the rotation step');
	ok( $body, 'the verb step holds one run body' ) or return;

	my @steps = $body =~ /^\s*(\w+)\)$/gm;
	ok( scalar @steps, 'the verb step names one step word at least' );

	my @arguments = _arguments( $body, @steps );
	my %passes;
	for my $argument (@arguments) {
		my ( $step, $option ) = @{$argument};
		$passes{$step}{$option} = 1;
	}

	for my $step (@steps) {
		ok( $passes{$step}{dir}, "a $step names the key directory" );
	}

	ok( $passes{mint}{bootstrap},   'a mint states the bootstrap intent' );
	ok( $passes{import}{bootstrap}, 'and so does an import' );
	ok( !$passes{promote}{bootstrap},
		'and a promote makes no key directory' );

	# The word reaches the verb from the input alone, so a caller
	# that leaves it false makes no directory.
	like(
		$body,
		qr/if \[ "\$BOOTSTRAP" = true \]; then\n\s*args\+=\(--bootstrap\)/,
		'the intent reaches the verb from the input'
	);
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
# the root step reads it to name the bound keys. _with_statuses of
# Rotate.pm reads a key block in two forms alone, and the two
# patterns of the step take those two. Fugu::Config takes a comment
# behind a value, and t/fuguweb/rotate.t holds a description that
# carries one. A read that missed it would drop the key, and the step
# would write no binding for it.
subtest 'the root step reads the status of each key block' => sub {
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

# _step_body($name):
#	The body of the run: block of one named step, as text. The
#	body keeps the indentation of the block, which no shell reads.
sub _step_body ($name)
{
	my ( $indent, @block );

	my $at;
	for my $i ( 0 .. $#lines ) {
		next unless $lines[$i] eq "      - name: $name";
		$at = $i;
		last;
	}
	return unless defined $at;

	for my $j ( $at + 1 .. $#lines ) {
		unless ( defined $indent ) {
			last if $lines[$j] =~ /^      - name: /;
			next unless $lines[$j] =~ /^(\s+)run: \|$/;
			$indent = length $1;
			next;
		}

		last
		    if $lines[$j] =~ /\S/
		    && $lines[$j] =~ /^(\s*)/
		    && length($1) <= $indent;
		push @block, $lines[$j];
	}

	return join "\n", @block;
}

# WEB-TRUST-7. A key stem is <org>-<serial>-<purpose>, and a purpose
# word holds a hyphen of its own. A match on the last field alone
# would give the key of pre-release to the purpose release, and the
# step would then bind it with the private half of another purpose.
# The step reads a description and two slot files, so it needs no
# runner and this subtest runs it over a fixture.
subtest 'the root step binds each key to the slot of its purpose' => sub {
	my $body = _step_body('Name the bound keys of a root step');
	ok( $body, 'the root step holds one run body' ) or return;

	my $dir  = File::Temp->newdir;
	my $work = "$dir/work";
	mkdir $work or die "mkdir $work: $!";

	_write( "$dir/step.sh", "$body\n" );
	_write( "$work/$_.sec", "the private half of the $_ key\n" )
	    for qw(release-active release-idle pre-release-active
	    pre-release-idle);

	# Two purposes, and the name of the first ends the name of the
	# second. Each one holds a current key and a next key.
	_write( "$dir/.fuguwebrc", <<~'RC' );
		key "fugubsd-1-release" {
			status = current
		}

		key "fugubsd-2-release" {
			status = next
		}

		key "fugubsd-1-pre-release" {
			status = current
		}

		key "fugubsd-2-pre-release" {
			status = next
		}
		RC

	# A first root mint finds no root slot file, so the step binds
	# each subordinate key again.
	my $cmd =
	      qq{cd "$dir" && WORK="$work" STEP=mint }
	    . qq{SUBORDINATE="release pre-release" }
	    . qq{GITHUB_OUTPUT="$dir/output" bash step.sh 2>&1};
	my $out = qx{$cmd};
	is( $?, 0, 'the step answers zero' ) or diag($out);

	my $args = _slurp("$work/bind.args") // q{};
	is_deeply(
		[ split /\n/, $args ],
		[
			"fugubsd-1-release=$work/release-active.sec",
			"fugubsd-2-release=$work/release-idle.sec",
			"fugubsd-1-pre-release=$work/pre-release-active.sec",
			"fugubsd-2-pre-release=$work/pre-release-idle.sec",
		],
		'each key takes the slot file of its own purpose'
	) or diag($args);

	# WEB-TRUST-7. A root mint that finds the root key of the
	# current slot binds nothing, and the run drops the list. The
	# step says so, and it names the purposes that it drops.
	_write( "$work/root-active.sec", "the private half of the root\n" );
	my $second = qx{$cmd};
	is( $?, 0, 'the second root mint answers zero' ) or diag($second);
	like(
		$second,
		qr/binds no key of: release pre-release/,
		'the step names the subordinate list that it drops'
	);
	like( _slurp("$dir/output") // q{},
		qr/^bind=no$/m, 'the step answers bind=no' );
};

# WEB-ACTIONS-3. A caller can compose keys-slot on its own, and that
# caller passes no guard of the workflow. A list of whitespace holds
# no word, and the action would write no file and answer an empty
# slot. A word that leaves the directory would write a private key
# outside it. Each guard runs before the first read of a variable, so
# this subtest needs no token and no runner.
subtest 'keys-slot refuses a purpose list that names no key' => sub {
	my ($body) = _bodies( _slurp($slot) // q{} );
	ok( $body, 'keys-slot holds one run body' ) or return;

	my $dir = File::Temp->newdir;
	_write( "$dir/action.sh", "$body\n" );

	my @cases = (
		[ '   ',        'keys-slot: the purpose list is empty' ],
		[ '../../evil', 'is no lower-case word' ],
		[ '-flag',      'is no lower-case word' ],
	);

	for my $case (@cases) {
		my ( $purpose, $want ) = @{$case};
		my $cmd =
		      qq{cd "$dir" && PURPOSE="$purpose" }
		    . qq{WORK="$dir/work" bash action.sh 2>&1};
		my $out = qx{$cmd};

		isnt( $?, 0, "keys-slot refuses the list '$purpose'" )
		    or diag($out);
		like( $out, qr/\Q$want\E/, "and it names the fault: $want" )
		    or diag($out);
	}
};

done_testing();
