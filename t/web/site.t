#!/usr/bin/env perl
# ex:ts=8 sw=4:
# The repository builds its own website, with its own description.
#
# Every other test writes a fixture, and a fixture names its own
# out_dir. The description of this repository names none, so it takes
# the defaults: source_dir web, and out_dir web/build. That output
# directory sits inside that source directory, and a guard that read
# the two as one refused the layout that the tool ships. The whole
# suite stayed green through it, because no test built the real
# description.
#
# The build writes into web/build, which .gitignore holds.

use v5.36;
use Test::More;
use FindBin qw($RealBin);
use lib "$RealBin/../../lib";
use File::Path qw(remove_tree);

# have($tool):
#	Report whether the program is on the path.
sub have ($tool)
{
	return system("command -v $tool >/dev/null 2>&1") == 0;
}

# The build drives the renderers, so the skip comes before the first
# assertion. A plan that arrives after one is not a plan.
plan skip_all => 'mandoc not found'  unless have('mandoc');
plan skip_all => 'lowdown not found' unless have('lowdown');
plan skip_all => 'pod2man not found' unless have('pod2man');

use_ok('App::FuguWeb::Config');
use_ok('App::FuguWeb::Render');
use_ok('App::FuguWeb::Site');
use_ok('App::FuguWeb::Check');
use_ok('Fugu::Log');

my $root = "$RealBin/../..";

my $config = App::FuguWeb::Config->load( root => $root, error => \my $reason );
ok( $config, 'the description of this repository loads' ) or do {
	diag $reason;
	done_testing();
	exit;
};

# The defaults are the point of this file. A description that named
# either setting would exercise another layout.
is( $config->source_dir, App::FuguWeb::Config::DEFAULT_SOURCE_DIR(),
	'it takes the default source directory' );
is( $config->out_dir, App::FuguWeb::Config::DEFAULT_OUT_DIR(),
	'and the default output directory' );

my $out = "$root/" . $config->out_dir;
remove_tree($out) if -d $out;

my $log = Fugu::Log->new( mode => Fugu::Log::MODE_QUIET() );

# site():
#	A site over this repository, into the default output.
sub site ()
{
	return App::FuguWeb::Site->new(
		config => $config,
		out    => $out,
		log    => $log,
		render => App::FuguWeb::Render->new( config => $config ),
	);
}

ok( site()->build, 'the build succeeds into the default output' );
ok( -f "$out/index.html",  'and it writes the entry page' );
ok( -f "$out/style.css",   'and the stylesheet' );

my @problems = App::FuguWeb::Check->new( config => $config, out => $out )->run;
is_deeply( \@problems, [], 'the checks pass on the built site' )
    or diag join "\n", @problems;

ok( site()->build, 'a second build succeeds over the same tree' );

ok( site()->clean, 'the clean takes the default output' );
ok( !-e $out, 'and the tree is gone' );

ok( -f "$root/.fuguwebrc",         'the description is untouched' );
ok( -d "$root/web",                'and the source directory' );
ok( -f "$root/web/index.body.html", 'and its files' );

done_testing();
