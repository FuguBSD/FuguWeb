#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Guards for scripts/ that no single script's own test would catch
#
# Names in scripts/ carry no extension. Thus only the shebang says
# what language a file is in. Several call sites invoke them as bare
# paths: the Makefile, scripts/deps, CI. A lost exec bit or a broken
# shebang thus fails at use, not at build.

use v5.36;
use Test::More;
use FindBin  qw($RealBin);
use File::Glob qw(bsd_glob);

my $root = "$RealBin/../..";
my $dir  = "$root/scripts";

# Named, not globbed: a script that disappears must fail here. The
# list must not shrink silently.
my @scripts = qw(deps dist ftp spec-check ste-lint);

for my $name (@scripts) {
	my $path = "$dir/$name";

	ok( -f $path, "scripts/$name exists" ) or next;
	ok( -x $path, "scripts/$name is executable" );

	open my $fh, '<', $path or do {
		fail("scripts/$name is readable");
		next;
	};
	my $shebang = <$fh>;
	close $fh;

	like( $shebang, qr{\A\#!\S*/(?:env )?(?:sh|perl)\b},
		"scripts/$name has an sh or perl shebang" );
}

# Every Perl script compiles. make lint and make tidy already read
# them, but neither runs the compiler. CI's perl -cw sweep covers only
# lib/ and bin/.
for my $name (@scripts) {
	my $path = "$dir/$name";
	next unless -f $path;

	open my $fh, '<', $path or next;
	my $shebang = <$fh>;
	close $fh;
	next unless $shebang =~ /perl/;

	my $output = `$^X -c "$path" 2>&1`;
	is( $? >> 8, 0, "scripts/$name compiles" ) or diag($output);
}

# Nothing under scripts/ regained an extension or an underscore
{
	opendir my $dh, $dir or die "opendir $dir: $!";
	my @found = sort grep { !/\A\.\.?\z/ } readdir $dh;
	closedir $dh;

	is_deeply( \@found, [ sort @scripts ],
		'scripts/ holds exactly the expected files' );

	my @odd = grep { /[_.]/ } @found;
	is_deeply( \@odd, [], 'no script name has an underscore or extension' );
}

subtest 'each manifest names an environment that deps installs' => sub {

	# scripts/deps is a synced file, and its environment list
	# grows in FuguBSD/Tooling. A manifest line that names a word
	# the local copy does not know installs nothing, and it says
	# nothing: a test that needed the package then skips, and the
	# suite stays green.
	my $script = _slurp("$dir/deps") or return;
	my ($list) = $script =~ /^use constant ENVIRONMENTS => qw\(([^)]*)\)/m;
	ok( $list, 'scripts/deps names its environments' ) or return;

	my %known = map { $_ => 1 } split ' ', $list;
	ok( %known, 'and the list holds a word' ) or return;

	my @manifests = bsd_glob("$root/deps/*.txt");
	ok( @manifests, 'the glob found a manifest' ) or return;

	for my $path (@manifests) {
		my ($file) = $path =~ m{([^/]+)\z};
		next if $file eq 'KEYS.txt' || $file eq 'SHA256.txt';

		my $text = _slurp($path) or next;
		my $line = 0;
		for my $entry ( split /\n/, $text ) {
			$line++;
			next if $entry =~ /^\s*(?:\#.*)?$/;

			my ($env) = $entry =~ /^(\S+)/;
			ok( $known{$env},
				"deps/$file line $line names the environment"
				    . " $env, which scripts/deps installs" );
		}
	}
};

# _slurp($path):
#	Whole file as text, or undef with a failed assertion.
sub _slurp ($path)
{
	open my $fh, '<', $path or do {
		fail("$path is readable");
		return;
	};
	local $/ = undef;
	my $text = <$fh>;
	close $fh;

	return $text;
}

done_testing();
