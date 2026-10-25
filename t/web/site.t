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
ok( -f "$out/en/index.html", 'and it writes the entry page of en' );
ok( -f "$out/style.css",     'and the stylesheet at the top level' );

# The top level forwards a visitor of the root into the tree of en.
my $forward = Fugu::File->read("$out/index.html") // '';
like( $forward, qr{<meta http-equiv="refresh" content="0; url=en/index\.html">},
	'the forward sends the root to the tree of en' );

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
# a hex color or a color function in what remains sits outside every
# property.
( my $rules = $sheet ) =~ s/:root\s*\{[^}]*\}//g;
unlike( $rules, qr/#[0-9a-fA-F]{3,8}|\b(?:rgba?|hsla?|color-mix)\(/,
    'no color literal outside the :root blocks' );

# WEB-STYLE-3 gives each color once. A value that two properties of
# one block share is one color under two names, so the check reads
# each :root block on its own.
my @twice;
my $block = 0;
for my $root ( $sheet =~ /:root\s*\{([^}]*)\}/g ) {
	$block++;
	my %count;
	$count{ lc $_ }++ for $root =~ /#[0-9a-fA-F]{3,8}/g;
	push @twice, map {"$_ in :root block $block"}
	    sort grep { $count{$_} > 1 } keys %count;
}
is_deeply( \@twice, [], 'each color appears once within a :root block' )
    or diag join "\n", @twice;

like( $sheet, qr/"Times New Roman"/, 'the body face is Times' );
like( $sheet, qr/Courier/,           'and the code face is Courier' );

# WEB-STYLE-4 bounds the measure and the rhythm of the body rule. The
# narrow query sets a max-width of its own, so each value comes from
# the body rule alone, and not from the sheet at large.
my ($body) = $sheet =~ /^body\s*\{([^}]*)\}/m;
my ($measure) = ( $body // '' ) =~ /\bmax-width:\s*([\d.]+)em\b/;
my ($rhythm)  = ( $body // '' ) =~ /\bline-height:\s*([\d.]+)\s*;/;
ok( defined $measure && $measure <= 42, 'the measure stops at 42em' )
    or diag 'max-width: ' . ( $measure // 'none' );
ok( defined $rhythm && $rhythm >= 1.5 && $rhythm <= 1.6,
    'and the line height sits between 1.5 and 1.6' )
    or diag 'line-height: ' . ( $rhythm // 'none' );

# WEB-STYLE-6 draws the underline one pixel thick, below the baseline.
# The chrome and the permalink carry a link rule of their own, so the
# match reads the one that starts the line.
my ($link) = $sheet =~ /^a:link\b[^{]*\{([^}]*)\}/m;
like( $link // '', qr/\btext-decoration-thickness:\s*1px\b/,
    'the underline of a link is one pixel' );
my ($offset) = ( $link // '' ) =~ /\btext-underline-offset:\s*([\d.]+)/;
ok( defined $offset && $offset > 0, 'and it sits below the baseline' )
    or diag 'text-underline-offset: ' . ( $offset // 'none' );

# declarations($text, $selector):
#	The declarations of each rule in the text that has a selector the
#	pattern matches, in the order of the sheet. A selector list splits
#	at each comma.
sub declarations ( $text, $selector )
{
	my $found = '';
	while ( $text =~ /([^{}]+)\{([^{}]*)\}/g ) {
		my ( $list, $body ) = ( $1, $2 );
		$found .= "$body;"
		    if grep {/$selector/} map { s/^\s+|\s+$//gr } split /,/, $list;
	}
	return $found;
}

# value($text, $selector, $property):
#	The value that the cascade gives the property in the rules of one
#	selector. Those rules share one specificity, so the last one wins.
#	The whitespace of the value folds to one space.
sub value ( $text, $selector, $property )
{
	my @found = declarations( $text, qr/^\Q$selector\E$/ )
	    =~ /(?<![-\w])\Q$property\E\s*:\s*([^;]*?)\s*;/g;
	return @found ? $found[-1] =~ s/\s+/ /gr : undef;
}

# A rule outside every query applies in each scheme and at each width.
# The light :root block is the one that no query encloses.
( my $plain = $sheet ) =~ s/\@media[^{]*\{(?:[^{}]*\{[^{}]*\})*[^{}]*\}//g;

# WEB-STYLE-3 gives the light scheme the gray ground of NCSA Mosaic.
is( lc( value( $plain, ':root', '--bg' ) // '' ), '#bfbfbf',
    'the light ground is the gray of NCSA Mosaic' );

# WEB-STYLE-5 draws the rule of 1994, a dark line over a light line,
# above the main part, the footer and each h2. A body fragment can
# hold an hr, and it takes the same rule. WEB-STYLE-6 gives a visited
# link its own color, and WEB-STYLE-8 sets a pre block as a terminal
# in a sunken well. WEB-STYLE-9 sets each list of the chrome on one
# line, draws the separator between two items, and shows the current
# link with no underline.
my @declarations = (
	[ 'main',          'border-top',    '1px solid var(--shadow)' ],
	[ 'main',          'box-shadow',    'inset 0 1px var(--highlight)' ],
	[ 'footer',        'border-top',    '1px solid var(--shadow)' ],
	[ 'footer',        'box-shadow',    'inset 0 1px var(--highlight)' ],
	[ 'hr',            'border-top',    '1px solid var(--shadow)' ],
	[ 'hr',            'border-bottom', '1px solid var(--highlight)' ],
	[ 'h2',            'border-top',    '1px solid var(--shadow)' ],
	[ 'h2',            'box-shadow',    'inset 0 1px var(--highlight)' ],
	[ 'body > header ul', 'list-style', 'none' ],
	[ 'nav ul',           'list-style', 'none' ],
	[ 'body > header li', 'display',    'inline' ],
	[ 'nav li',           'display',    'inline' ],
	[ 'body > header li + li::before', 'content', '"\\00b7"' ],
	[ 'nav li + li::before',           'content', '"\\00b7"' ],
	[ 'a[aria-current="page"]:link',    'text-decoration', 'none' ],
	[ 'a[aria-current="page"]:visited', 'text-decoration', 'none' ],
	[ 'table.head td', 'box-shadow',    'inset 0 -1px var(--shadow)' ],
	[ 'table.head td', 'border-bottom', '1px solid var(--highlight)' ],
	[ 'table.foot td', 'border-top',    '1px solid var(--shadow)' ],
	[ 'table.foot td', 'box-shadow',    'inset 0 1px var(--highlight)' ],
	[ 'h2.Ss',         'border',        '0' ],
	[ 'h2.Ss',         'box-shadow',    'none' ],
	[ 'a:visited',     'color',         'var(--visited)' ],
	[ 'pre',           'background',    'var(--term-bg)' ],
	[ 'pre',           'color',         'var(--term-fg)' ],
	[ 'pre',           'border',        '2px solid' ],
	[   'pre', 'border-color',
	    'var(--shadow) var(--highlight) var(--highlight) var(--shadow)'
	],
);
for (@declarations) {
	my ( $selector, $property, $want ) = @$_;
	is( value( $plain, $selector, $property ),
	    $want, "$selector takes $property: $want" );
}

# WEB-STYLE-5 takes the band of the earlier design away. A band is a
# background or a border, so no rule of an h1 sets either.
unlike(
	declarations( $sheet, qr/^h1(?![\w-])/ ),
	qr/(?<![-\w])(?:border|background)[\w-]*\s*:/,
	'no h1 takes a band'
);

# WEB-STYLE-6 needs a visited color apart from the link color, in each
# :root block. An alias of one to the other is the same color.
my @alike;
$block = 0;
for my $root ( $sheet =~ /:root\s*\{([^}]*)\}/g ) {
	$block++;
	my %value = "$root;" =~ /(--[\w-]+)\s*:\s*([^;]*?)\s*;/g;
	my @pair  = map { $value{$_} // '' } qw(--link --visited);
	s{^var\((--[\w-]+)\)$}{$value{$1} // ''}e for @pair;
	push @alike, ":root block $block"
	    unless length $pair[0] && length $pair[1]
	    && lc $pair[0] ne lc $pair[1];
}
is_deeply( \@alike, [], 'the visited color differs from the link color' )
    or diag join "\n", @alike;

# luminance($color):
#	The WCAG relative luminance of a hex color, or undef for any other
#	value.
sub luminance ($color)
{
	my ($hex) = $color =~ /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})$/ or return;
	$hex =~ s/(.)/$1$1/g if length $hex == 3;
	my @linear = map {
		my $c = hex($_) / 255;
		$c <= 0.04045 ? $c / 12.92 : ( ( $c + 0.055 ) / 1.055 )**2.4;
	} $hex =~ /(..)/g;
	return 0.2126 * $linear[0] + 0.7152 * $linear[1] + 0.0722 * $linear[2];
}

# WEB-STYLE-5 needs the dark line of the rule darker than its light
# line, and WEB-STYLE-8 needs the ground of a terminal darker than its
# text. The dark :root block overrides the light one, so each block
# reads over the values of the blocks before it.
my %scheme;
$block = 0;
for my $root ( $sheet =~ /:root\s*\{([^}]*)\}/g ) {
	$block++;
	%scheme = ( %scheme, "$root;" =~ /(--[\w-]+)\s*:\s*([^;]*?)\s*;/g );
	for my $pair ( [qw(--shadow --highlight)], [qw(--term-bg --term-fg)] ) {
		my @color = map { $scheme{$_} // '' } @$pair;
		s{^var\((--[\w-]+)\)$}{$scheme{$1} // ''}e for @color;
		my @tone = map { scalar luminance($_) } @color;
		ok( defined $tone[0] && defined $tone[1] && $tone[0] < $tone[1],
		    "$pair->[0] is darker than $pair->[1] in :root block $block" )
		    or diag join ' ', @color;
	}
}

# WEB-STYLE-9 reaches each list of the chrome by element name and
# attribute alone, so the chrome writes the elements that the sheet
# names, and no class.
my $index = Fugu::File->read("$out/en/index.html") // '';
like( $index, qr/<header>/, 'the chrome writes a bare header' );
like( $index, qr{<nav>\n<ul>\n<li><a href="index\.html" aria-current="page">},
	'and a nav list, with the current page' );
unlike( $index, qr/<hr>/,   'and no rule' );
unlike( $index, qr/class=/, 'and no class' );

ok( site()->build, 'a second build succeeds over the same tree' );

ok( site()->clean, 'the clean takes the default output' );
ok( !-e $out, 'and the tree is gone' );

ok( -f "$root/.fuguwebrc",         'the description is untouched' );
ok( -d "$root/web",                'and the source directory' );
ok( -f "$root/web/index.body.html", 'and its files' );

done_testing();
