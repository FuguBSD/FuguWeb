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
use_ok('Fugu::File');

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

# The sheet of the built site is the one that ships, and WEB-STYLE
# binds it. The tests below hold each rule that a byte of the sheet
# can answer. A comment may name a host or a site, and that dot would
# read as a class, so the comments go first.
my $sheet = Fugu::File->read("$out/style.css") // '';
$sheet =~ s{/\*.*?\*/}{}gs;

# The chrome carries no class, and a body fragment carries none. The
# class names that mandoc(1) emits are the one set the sheet may use.
my %mandoc = map { $_ => 1 } qw(
    head foot head-vol foot-date head-rtitle foot-os
    Sh Ss permalink manual-text Nm Bd-indent Bl-tag
    Cm Fl Ic Fn Dv Er Ev Ar Va Pa Em
);
my %seen;
my @foreign = grep { !$mandoc{$_} && !$seen{$_}++ }
    $sheet =~ /\.([A-Za-z_-][\w-]*)/g;
is_deeply( \@foreign, [], 'no class selector outside the mandoc set' )
    or diag join ' ', @foreign;

unlike( $sheet, qr/url\(/,    'the sheet loads no resource' );
unlike( $sheet, qr/\@import/, 'and imports no sheet' );

my @schemes = $sheet =~ /prefers-color-scheme/g;
is( scalar @schemes, 1, 'one query selects the dark scheme' );

# WEB-STYLE-3 puts each color in a custom property, so a literal lives
# in a :root block alone. The light block goes, the dark one goes, and
# a hex color in what remains sits outside every property.
( my $rules = $sheet ) =~ s/:root\s*\{[^}]*\}//g;
unlike( $rules, qr/#[0-9a-fA-F]{3,8}/, 'no color literal outside the :root blocks' );

like( $sheet, qr/"Times New Roman"/, 'the body face is Times' );
like( $sheet, qr/Courier/,           'and the code face is Courier' );

my $index = Fugu::File->read("$out/index.html") // '';
like( $index, qr/<header>/, 'the chrome writes a bare header' );
unlike( $index, qr/class="banner"/, 'and no banner class' );

ok( site()->build, 'a second build succeeds over the same tree' );

ok( site()->clean, 'the clean takes the default output' );
ok( !-e $out, 'and the tree is gone' );

ok( -f "$root/.fuguwebrc",         'the description is untouched' );
ok( -d "$root/web",                'and the source directory' );
ok( -f "$root/web/index.body.html", 'and its files' );

done_testing();
