#!/usr/bin/env perl
# ex:ts=8 sw=4:
# App::FuguWeb::Site: a small site builds into the tree of its
# language, holds what the description names and nothing else, drops
# the staging directory, and builds a second time to the same bytes.
#
# The test builds its site in a File::Temp directory. It never reads
# the repository; t/web/site.t covers the real site.

use v5.36;
use Test::More;
use FindBin qw($RealBin);
use lib "$RealBin/../../lib";
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);

# have($tool):
#	Report whether the program is on the path.
sub have ($tool)
{
	return system("command -v $tool >/dev/null 2>&1") == 0;
}

# The whole file drives the renderers, so the skip comes before the
# first assertion. A plan that arrives after one is not a plan.
plan skip_all => 'mandoc not found'  unless have('mandoc');
plan skip_all => 'lowdown not found' unless have('lowdown');
plan skip_all => 'pod2man not found' unless have('pod2man');

use_ok('App::FuguWeb::Config');
use_ok('App::FuguWeb::Render');
use_ok('App::FuguWeb::Site');
use_ok('Fugu::Log');

my $RC = <<'RC';
site       = Example
source_dir = web
out_dir    = out

nav "index.html" {
	label = Home
}

page "index.html" {
	title = Home
	body  = index.body.html
}

page "readme.html" {
	title    = Readme
	markdown = README.md
}

page "manuals.html" {
	title = Manuals
	index = yes
}

page "404.html" {
	title    = Not found
	body     = 404.body.html
	unlinked = yes
}

manuals "Manuals" {
	dir    = man
	anchor = manuals
}

modules "Modules" {
	dir    = lib/Thing
	anchor = modules
}
RC

# project():
#	Write a whole small project and return its root.
sub project ()
{
	my $root = tempdir( CLEANUP => 1 );

	my %file = (
		'.fuguwebrc'          => $RC,
		'README.md'           => "# Readme\n\nA paragraph.\n",
		'web/index.body.html' => "<h1>Home</h1>\n",
		'web/404.body.html'   =>
		    qq{<h1>Not found</h1>\n<p><a href="index.html">Home</a></p>\n},
		'web/footer.body.html' => "<p>ISC.</p>\n",
		'web/robots.txt'      => "User-agent: *\n",

		# Not an asset: a note for the maintainers, not content
		'web/CLAUDE.md' => "# web/\n\nNotes.\n",

		'man/tool.1' => <<'MDOC',
.Dd $Mdocdate: July 27 2026 $
.Dt TOOL 1
.Os
.Sh NAME
.Nm tool
.Nd a tool
.Sh DESCRIPTION
Words.
MDOC
		'lib/Thing/Depot.pod' => <<'POD',
=head1 NAME

Thing::Depot - the persistence contract

=head1 DESCRIPTION

Words.
POD
	);

	for my $relative ( sort keys %file ) {
		my $path = "$root/$relative";
		make_path( $path =~ s{/[^/]+$}{}r );

		open my $fh, '>', $path or die "Cannot write $path: $!";
		print {$fh} $file{$relative};
		close $fh;
	}

	return $root;
}

# site($root, $out):
#	A site over the project, with a quiet log.
sub site ( $root, $out )
{
	my $config =
	    App::FuguWeb::Config->load( root => $root, error => \my $reason );
	die "$reason\n" unless $config;

	return App::FuguWeb::Site->new(
		config => $config,
		out    => $out,
		log    => Fugu::Log->new( mode => Fugu::Log::MODE_QUIET() ),
	);
}

my $ROOT = project();
my $OUT  = tempdir( CLEANUP => 1 ) . '/out';

subtest 'the build makes the site and nothing else' => sub {
	my $site = site( $ROOT, $OUT );
	ok( $site->build, 'the build succeeds' );
	is( $site->missing_tool, undef, 'and records no missing tool' );

	# The probe is the first step, so the failure names the tool
	# that is missing. Without it the build reaches the lint and
	# reports that a manual source was rejected, which sends the
	# reader to the wrong place.
	my $absent = tempdir( CLEANUP => 1 ) . '/out';
	my $config = site( $ROOT, $absent )->config;
	my $said   = '';

	open my $saved, '>&', \*STDERR or die "Cannot save stderr: $!";
	close STDERR;
	open STDERR, '>', \$said or die 'Cannot capture stderr';

	my $broken = App::FuguWeb::Site->new(
		config => $config,
		out    => $absent,
		render => App::FuguWeb::Render->new(
			config => $config,
			mandoc => '/nonexistent/mandoc',
		),
	);
	my $failed = $broken->build;

	close STDERR;
	open STDERR, '>&', $saved or die "Cannot restore stderr: $!";

	ok( !$failed, 'a build with no mandoc fails' );
	is( $broken->missing_tool, '/nonexistent/mandoc',
		'and the build records the missing tool' );
	like( $said, qr{/nonexistent/mandoc is not installed},
		'and names the tool that is missing' );
	unlike( $said, qr/rejected a manual source/,
		'and does not blame a manual for it' );
	ok( !-e $absent, 'and writes nothing' );

	# The pages of the description and one page per manual, in the
	# tree of en. The forward, the copy of the 404 page, the base
	# stylesheet, and the assets at the top level.
	my @expected = qw(
	    404.html en/404.html en/Thing::Depot.3p.html en/index.html
	    en/manuals.html en/readme.html en/tool.1.html
	    index.html robots.txt style.css
	);
	ok( -s "$OUT/$_", "$_ exists and is not empty" ) for @expected;

	# Staging is a build detail and never part of the published
	# tree.
	ok( !-e "$OUT/.man", 'the staging directory is gone' );

	is_deeply( App::FuguWeb::list_tree($OUT), \@expected,
		'the output holds the site only' );
};

subtest 'the top level holds the forward and the 404 page' => sub {
	open my $fh, '<', "$OUT/index.html" or die "Cannot read: $!";
	my $forward = do { local $/; <$fh> };
	close $fh;

	# WEB-LANG-8. One meta refresh, one link, and nothing loaded.
	is( $forward, <<'HTML', 'the forward is byte for byte its shape' );
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="0; url=en/index.html">
<title>Example</title>
</head>
<body>
<p><a href="en/index.html">Example</a></p>
</body>
</html>
HTML

	# WEB-LANG-9. The copy is the page of the default language,
	# with its base, and its chrome links the default tree.
	open $fh, '<', "$OUT/404.html" or die "Cannot read: $!";
	my $copy = do { local $/; <$fh> };
	close $fh;

	like( $copy, qr{<html lang="en">}, 'the copy is a page of en' );
	like( $copy, qr{<base href="/">\n<title>Not found },
		'with its base before the title' );
	like( $copy, qr{<link rel="stylesheet" href="style\.css">},
		'the stylesheet beside it' );
	like( $copy, qr{<header><a href="en/index\.html">Example</a>},
		'the header link into the default tree' );
	like( $copy, qr{<nav>\n<a href="en/index\.html">Home</a>\n</nav>},
		'and the nav link' );
	like( $copy, qr{<p><a href="index\.html">Home</a></p>},
		'the body fragment as it stands' );
	unlike( $copy, qr/<footer>/, 'and no footer' );

	open $fh, '<', "$OUT/en/404.html" or die "Cannot read: $!";
	my $tree = do { local $/; <$fh> };
	close $fh;

	like( $tree, qr{<footer>}, 'the 404 page of the tree takes the footer' );
	unlike( $tree, qr{<base}, 'and no base' );
};

subtest 'each source reaches its page' => sub {
	open my $fh, '<', "$OUT/en/readme.html" or die "Cannot read: $!";
	my $readme = do { local $/; <$fh> };
	close $fh;
	like( $readme, qr/A paragraph\./, 'lowdown rendered the Markdown' );

	open $fh, '<', "$OUT/en/manuals.html" or die "Cannot read: $!";
	my $index = do { local $/; <$fh> };
	close $fh;
	like( $index, qr{href="\./tool\.1\.html"}, 'the index lists the page' );
	like( $index, qr/a tool/, 'with the description of its source' );
	like( $index, qr{href="\./Thing::Depot\.3p\.html"},
		'and the sidecar' );

	open $fh, '<', "$OUT/en/Thing::Depot.3p.html" or die "Cannot read: $!";
	my $module = do { local $/; <$fh> };
	close $fh;
	like( $module, qr/the persistence contract/,
		'pod2man and mandoc rendered the sidecar' );
	like( $module, qr{<title>Thing::Depot\(3p\) },
		'and the chrome carries the title' );
	like( $module, qr{<html lang="en">}, 'the page is a page of en' );
	like( $module, qr{<link rel="stylesheet" href="\.\./style\.css">},
		'it links the stylesheet one step up' );
	like( $module, qr{<header><a href="index\.html">Example</a>},
		'and the entry page of its tree by name' );
	like( $module, qr{<footer>\n<p>ISC\.</p>\n</footer>},
		'and it carries the footer' );
};

subtest 'the site is a pure function of the project' => sub {
	my $second = tempdir( CLEANUP => 1 ) . '/out';
	ok( site( $ROOT, $second )->build, 'the second build succeeds' );

	my $diff = `diff -r '$OUT' '$second' 2>&1`;
	is( $diff, '', 'two builds are byte-identical' );
};

subtest 'a second build over the same directory succeeds' => sub {
	my $site = site( $ROOT, $OUT );
	ok( $site->build, 'the build is idempotent' );
	ok( !-e "$OUT/.man", 'and leaves no staging behind' );
};

subtest 'a stylesheet that is not found fails the build' => sub {
	my $root = project();
	open my $fh, '>>', "$root/.fuguwebrc"
	    or die "Cannot append to the description: $!";
	print {$fh} "stylesheet = web/absent.css\n";
	close $fh;

	my $out = tempdir( CLEANUP => 1 ) . '/out';

	# A site with no stylesheet must not look like a success.
	ok( !site( $root, $out )->build, 'the build fails' );
};

subtest 'clean removes the output directory' => sub {
	my $site = site( $ROOT, $OUT );
	ok( -d $OUT, 'the output is there' );
	ok( $site->clean, 'clean succeeds' );
	ok( !-e $OUT, 'and the directory is gone' );

	ok( $site->clean, 'clean is idempotent' );
};

subtest 'pod_date is the date of the last commit' => sub {
	my $site = site( project(), tempdir( CLEANUP => 1 ) . '/out' );

	# A temporary project is no git checkout, so the fallback
	# answers. Either way the answer is a date and not a file time.
	like( $site->pod_date, qr/^\d{4}-\d{2}-\d{2}$/,
		'the date is an ISO date' );

	SKIP: {
		skip 'git not found', 1 unless have('git');

		# git does not preserve file times, so a build that read
		# one would give different bytes on every checkout. The
		# value has to be the commit date and not merely a date.
		my $root = project();
		my $quiet = '>/dev/null 2>&1';
		my $env = 'GIT_AUTHOR_DATE="2001-02-03T04:05:06 +0000"'
		    . ' GIT_COMMITTER_DATE="2001-02-03T04:05:06 +0000"'
		    . ' GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.org'
		    . ' GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.org';
		system("cd '$root' && git init -q $quiet") == 0
		    or skip 'git init failed', 1;
		system("cd '$root' && git add -A $quiet") == 0
		    or skip 'git add failed', 1;
		system("cd '$root' && $env git commit -qm one $quiet") == 0
		    or skip 'git commit failed', 1;

		is( site( $root, tempdir( CLEANUP => 1 ) . '/out' )->pod_date,
			'2001-02-03', 'the date of the last commit' );
	}
};

subtest 'a stale staging directory does not reach the next build' => sub {
	my $root = project();
	my $out  = tempdir( CLEANUP => 1 ) . '/out';

	# mandoc reads a cross-reference as a local link when a file of
	# that name sits in its working directory. A stale source left
	# by an interrupted build would therefore turn a reference that
	# belongs on the manual host into a link that leads nowhere.
	open my $fh, '>>', "$root/man/tool.1"
	    or die "Cannot extend the source: $!";
	print {$fh} ".Sh SEE ALSO\n.Xr ghost 1\n";
	close $fh;

	make_path("$out/.man/en");
	open my $ghost, '>', "$out/.man/en/ghost.1"
	    or die "Cannot write the stale source: $!";
	print {$ghost} ".Dd \$Mdocdate: July 27 2026 \$\n.Dt GHOST 1\n.Os\n"
	    . ".Sh NAME\n.Nm ghost\n.Nd a source no group names\n";
	close $ghost;

	ok( site( $root, $out )->build, 'the build succeeds' );
	ok( !-e "$out/.man",         'and the staging directory is gone' );
	ok( !-e "$out/en/ghost.1.html", 'the stale source rendered nothing' );

	open my $page, '<', "$out/en/tool.1.html" or die "Cannot read: $!";
	my $html = do { local $/; <$page> };
	close $page;

	like( $html, qr{href="https://man\.openbsd\.org/ghost\.1"},
		'and the cross-reference still leaves for the manual host' );
};

subtest 'a page the site no longer holds is removed' => sub {
	my $root = project();
	my $out  = tempdir( CLEANUP => 1 ) . '/out';

	ok( site( $root, $out )->build, 'the first build succeeds' );
	ok( -e "$out/en/tool.1.html", 'the manual has a page' );

	rename "$root/man/tool.1", "$root/man/renamed.1"
	    or die "Cannot rename the source: $!";

	ok( site( $root, $out )->build, 'the second build succeeds' );
	ok( -e "$out/en/renamed.1.html", 'the new page is there' );
	ok( !-e "$out/en/tool.1.html",   'and the old one is gone' );
};

subtest 'the build removes the old flat layout and a stale tree' => sub {
	my $root = project();
	my $out  = tempdir( CLEANUP => 1 ) . '/out';

	ok( site( $root, $out )->build, 'the first build succeeds' );

	# A page of the flat layout at the top level, and the tree of
	# a language that the description no longer holds.
	make_path("$out/de");
	for my $stale (qw(manuals.html tool.1.html de/index.html de/404.html))
	{
		open my $fh, '>', "$out/$stale" or die "Cannot write: $!";
		print {$fh} "<h1>Stale</h1>\n";
		close $fh;
	}

	ok( site( $root, $out )->build, 'the second build succeeds' );
	ok( !-e "$out/$_", "$_ is gone" )
	    for qw(manuals.html tool.1.html de/index.html de/404.html);
	ok( !-e "$out/de",           'and so is the stale tree' );
	ok( -e "$out/en/index.html", 'the tree of en stays' );
	ok( -e "$out/index.html",    'and so does the forward' );

	# A tree is one flat directory of pages. A deeper directory of
	# a tree belongs to whoever made it, and the build keeps it.
	make_path("$out/de/deep");
	open my $fh, '>', "$out/de/deep/keep.txt" or die "Cannot write: $!";
	print {$fh} "important\n";
	close $fh;

	ok( site( $root, $out )->build, 'a third build succeeds' );
	ok( -e "$out/de/deep/keep.txt", 'and keeps the deeper file' );
	ok( !site( $root, $out )->clean, 'which the clean refuses' );
	ok( -e "$out/en/index.html", 'and removes nothing' );
};

subtest 'the build refuses an output directory it must not own' => sub {
	my $root = project();

	# Every refused target, and the home directory through a HOME
	# of this test alone. --out reaches build and clean alike, and
	# the setting it overrides is checked in the description.
	my $home = tempdir( CLEANUP => 1 );
	local $ENV{HOME} = $home;

	my @bad = (
		$root, '/', "$root/..", File::Spec->rootdir,
		$home, "$root/web",
	);

	for my $bad (@bad) {
		ok( !site( $root, $bad )->build,
			"the build refuses $bad" );
		ok( !site( $root, $bad )->clean,
			"and the clean refuses it too" );
	}

	ok( -e "$root/.fuguwebrc",           'the project is untouched' );
	ok( -e "$root/web/index.body.html",  'and the source with it' );
	ok( -d $home,                        'and the home directory' );

	# A directory that no rule names still builds. The guard is
	# not "inside the project": the tests and the CI both build
	# into a temporary directory outside it.
	my $good = tempdir( CLEANUP => 1 ) . '/out';
	ok( site( $root, $good )->build, "the build takes $good" );

	# The output directory that the description names is the one
	# exception below the source. This description names out, so
	# web/build is a directory of the source like any other.
	ok( !site( $root, "$root/web/build" )->build,
		'the build refuses a source directory that it does not own' );
	ok( !site( $root, "$root/web/build" )->clean,
		'and the clean refuses it too' );
	ok( -e "$root/web/index.body.html", 'the source is untouched' );

	# t/web/site.t builds the description of this repository, which
	# names neither setting and therefore takes web/build.
};

subtest 'clean takes the trees and the staging of a build' => sub {
	my $root = project();
	my $out  = tempdir( CLEANUP => 1 ) . '/out';
	ok( site( $root, $out )->build, 'the build succeeds' );

	# A tree of another language and the staging of an interrupted
	# build are both shapes that a build writes, per WEB-OUTPUT-5.
	make_path( "$out/de", "$out/.man/en" );
	for my $made (qw(de/index.html .man/en/tool.1)) {
		open my $fh, '>', "$out/$made" or die "Cannot write: $!";
		print {$fh} "made\n";
		close $fh;
	}

	ok( site( $root, $out )->clean, 'the clean succeeds' );
	ok( !-e $out,                    'and the directory is gone' );
};

subtest 'the build refuses a staging directory of another shape' => sub {
	my $root = project();

	# WEB-OUTPUT-14. A build stages one flat directory of plain
	# files for each language. A plain file at the top of the
	# staging directory, and a directory of another name, are
	# each somebody else's.
	for my $stray ( '.man/tool.1', '.man/mine/notes.txt', '.man/en/deep/x.1' )
	{
		my $out = tempdir( CLEANUP => 1 ) . '/out';
		make_path( "$out/" . ( $stray =~ s{/[^/]+\z}{}r ) );
		open my $fh, '>', "$out/$stray" or die "Cannot write: $!";
		print {$fh} "theirs\n";
		close $fh;

		ok( !site( $root, $out )->build, "the build refuses $stray" );
		ok( -e "$out/$stray",            'and removes nothing' );
		ok( !site( $root, $out )->clean, 'and the clean refuses it too' );
	}
};

subtest 'clean refuses a directory that no build made' => sub {
	my $root = project();
	my $out  = tempdir( CLEANUP => 1 ) . '/out';
	make_path("$out/deep");

	open my $fh, '>', "$out/deep/keep.txt" or die "Cannot write: $!";
	print {$fh} "important\n";
	close $fh;

	ok( !site( $root, $out )->clean, 'clean fails' );
	ok( -e "$out/deep/keep.txt",     'and removes nothing' );
};

done_testing();
