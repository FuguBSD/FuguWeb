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
# The fit removes the head and the foot of a manual page, per D-07, so
# the set holds none of their classes.
my %mandoc = map { $_ => 1 } qw(
    Sh Ss permalink manual-text Nm Bd Bd-indent Bl-tag
    Cm Fl Ic Fn Dv Er Ev Ar Va Pa Em
);
my %seen;
my @foreign = grep { !$mandoc{$_} && !$seen{$_}++ }
    $sheet =~ /\.([A-Za-z_-][\w-]*)/g;
is_deeply( \@foreign, [], 'no class selector outside the mandoc set' )
    or diag join ' ', @foreign;

# WEB-STYLE-4 and WEB-STYLE-7 rely on two parts of the markup of
# mandoc(1): the pre block of an indented display of mdoc(7) as a
# child of the display, and the Pa macro as a span. The manual of
# fuguweb(1) holds both, so its built page shows that each rule
# matches.
my $manual = Fugu::File->read("$out/en/fuguweb.1.html") // '';
like( $manual, qr/<div class="Bd\b[^"]*\bBd-indent\b[^"]*">\s*<pre\b/,
	'an indented display of mdoc holds its pre block as a child' );
like( $manual, qr/<span class="Pa">/, 'and a path of mdoc is a span' );

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

# WEB-STYLE-4 bounds the measure of the body rule. The narrow query
# sets a max-width of its own, so the value comes from the body rule
# alone, and not from the sheet at large.
my ($body) = $sheet =~ /^body\s*\{([^}]*)\}/m;
my ($measure) = ( $body // '' ) =~ /\bmax-width:\s*([\d.]+)em\b/;
ok( defined $measure && $measure <= 42, 'the measure stops at 42em' )
    or diag 'max-width: ' . ( $measure // 'none' );

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
#	at each comma outside a pair of parentheses, so the list of an
#	:is() stays whole.
sub declarations ( $text, $selector )
{
	my $found = '';
	while ( $text =~ /([^{}]+)\{([^{}]*)\}/g ) {
		my ( $list, $body ) = ( $1, $2 );
		$list =~ s/(\((?:[^()]++|(?1))*\))/$1 =~ tr{,}{\0}r/ge;
		$found .= "$body;"
		    if grep {/$selector/}
		    map { tr{\0}{,}r =~ s/^\s+|\s+$//gr } split /,/, $list;
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
# hold an hr, and it takes the same rule. A section heading of a
# manual page is an h2, and it takes no rule. WEB-STYLE-6 gives a visited
# link its own color, a pressed link the red of Netscape 1.x, and the
# focus a dotted ring. Its underline runs through the descenders, and
# a linked image takes a frame. WEB-STYLE-4 takes the kerning and the
# common ligatures away. WEB-STYLE-8 sets a pre block as an xterm in the
# frame of twm, with the title hidden from a screen reader, and the
# selection in reverse video. The title bar keeps the order of X11 on
# a page of rtl. WEB-STYLE-9 sets each list of the chrome on one
# line, and the list of the languages at the end of the banner line.
# It draws the separator between two items, and puts the nav list in
# a pair of brackets. Each separator and each bracket is text with
# one word space. A space after a hex escape is part of the escape,
# so \20 writes the space after the dot. The sheet shows the current
# link with no underline and no bold. WEB-STYLE-4 gives a heading and
# a pre block their own line height. It gives each code face the size
# at which its letters cover the area of Times New Roman: Courier
# 0.846em, and the Menlo of a pre block 0.767em. A code element in a
# code element keeps the face and the size of its parent, so the size
# does not shrink twice. WEB-STYLE-7 gives a display of a pre block no indent.
# WEB-STYLE-8 gives a pre block the face of xterm, and the internal
# border of 2px of xterm under the title bar of 20px and its border.
my @declarations = (
	[ 'main',   'border-block-start', '1px solid var(--shadow)' ],
	[ 'main',   'box-shadow',         'inset 0 1px var(--highlight)' ],
	[ 'footer', 'border-block-start', '1px solid var(--shadow)' ],
	[ 'footer', 'box-shadow',         'inset 0 1px var(--highlight)' ],
	[ 'hr',     'border-block-start', '1px solid var(--shadow)' ],
	[ 'hr',     'border-block-end',   '1px solid var(--highlight)' ],
	[ 'h2',     'border-block-start', '1px solid var(--shadow)' ],
	[ 'h2',     'box-shadow',         'inset 0 1px var(--highlight)' ],
	[ 'body > header', 'display',         'flex' ],
	[ 'body > header', 'justify-content', 'space-between' ],
	[ 'body > header ul', 'list-style', 'none' ],
	[ 'nav ul',           'list-style', 'none' ],
	[ 'body > header li', 'display',    'inline' ],
	[ 'nav li',           'display',    'inline' ],
	[ 'body > header li + li::before', 'content', '"\\00b7\\20"' ],
	[ 'nav li + li::before',           'content', '"| "' ],
	[ 'nav ul::before',                'content', '"[ "' ],
	[ 'nav ul::after',                 'content', '" ]"' ],
	[ 'a[aria-current="page"]:link',    'text-decoration', 'none' ],
	[ 'a[aria-current="page"]:visited', 'text-decoration', 'none' ],
	[ 'a[aria-current="page"]:link',    'font-weight',     'normal' ],
	[ 'a[aria-current="page"]:visited', 'font-weight',     'normal' ],
	[ 'h2.Sh',         'border',        '0' ],
	[ 'h2.Sh',         'box-shadow',    'none' ],
	[ 'a:visited',     'color',         'var(--visited)' ],
	[ 'pre',           'background',    'var(--term-bg)' ],
	[ 'pre',           'color',         'var(--term-fg)' ],
	[ 'a:link',    'text-decoration-skip-ink', 'none' ],
	[ 'a:visited', 'text-decoration-skip-ink', 'none' ],
	[ 'a img',     'border',                   '2px solid' ],
	[ 'body',      'font-kerning',             'none' ],
	[ 'body',      'font-variant-ligatures',   'no-common-ligatures' ],
	[ 'a:active',     'color',        'var(--active)' ],
	[ ':focus-visible', 'outline',    '1px dotted' ],
	[ 'pre',          'border',       '2px solid var(--wm-border)' ],
	[ 'pre::before',  'content',      '"xterm" / ""' ],
	[ 'pre::before',  'direction',    'ltr' ],
	[ 'pre::before',  'color',        'var(--wm-title-fg)' ],
	[ 'pre::before',  'font-family',  'var(--wm-face)' ],
	[ 'pre::before',  'font-weight',  'bold' ],
	[ 'pre',          'white-space',  'pre-wrap' ],
	[ 'pre',          'overflow-wrap', 'anywhere' ],
	[ 'pre',          'overflow-x',   undef ],
	[ 'pre',          'overflow',     undef ],
	[ 'pre::after',   'direction',    'ltr' ],
	[ 'pre::selection',  'background-color', 'var(--term-fg)' ],
	[ 'pre ::selection', 'color',            'var(--term-bg)' ],
	( map { [ $_, 'line-height', '1.2' ] } qw(h1 h2 h3 h4 h5 h6) ),
	[ 'pre', 'line-height', '1.2' ],
	( map { [ $_, 'font-size', '0.846em' ] } qw(code tt kbd samp var .Pa) ),
	[ 'pre', 'font-size', '0.767em' ],
	[ ':is(code, pre, tt, kbd, samp, var, .Pa) :is(code, tt, kbd, samp, var, .Pa)',
	    'font-size', '1em' ],
	[ ':is(code, pre, tt, kbd, samp, var, .Pa) :is(code, tt, kbd, samp, var, .Pa)',
	    'font-family', 'inherit' ],
	[ '.Bd.Bd-indent:has(> pre)', 'margin-inline-start', '0' ],
	[ 'pre', 'font-family',    'var(--term-face)' ],
	[ 'pre', 'padding-block',  'calc(22px + 2px) 2px' ],
	[ 'pre', 'padding-inline', '2px' ],
);
for (@declarations) {
	my ( $selector, $property, $want ) = @$_;
	is( value( $plain, $selector, $property ),
	    $want, "$selector takes $property: " . ( $want // 'no value' ) );
}

# WEB-STYLE-8 takes the default colors of twm from its system.twmrc,
# and the even stipple of its highlight area. WEB-STYLE-6 takes the
# red of Netscape 1.x for a pressed link in the light scheme.
my %twm = (
	'--wm-border'   => '#708090',
	'--wm-title-bg' => '#22aa99',
	'--wm-title-fg' => '#d9d9d9',
	'--active'      => '#ff0000',
);
for ( sort keys %twm ) {
	is( lc( value( $plain, ':root', $_ ) // '' ),
	    $twm{$_}, "$_ takes $twm{$_}" );
}
is( value( $plain, ':root', '--wm-face' ),
	'Helvetica, Arial, sans-serif', 'the title face is Helvetica' );
is( value( $plain, ':root', '--term-face' ),
	'Menlo, "Lucida Console", "DejaVu Sans Mono", monospace',
	'the face of xterm is a sans-serif monospace' );

# The title bar takes the iconify dot in its box, then the title
# ground. The bar under it takes the resize button, two nested corners
# at the top left of a box, then the even stipple and the ground. The
# first layer paints on top, so each background holds its layers in
# this order, and in no other.
my $fg = 'linear-gradient(var(--wm-title-fg), var(--wm-title-fg))';
my $bg = 'linear-gradient(var(--wm-title-bg), var(--wm-title-bg))';
my %bar = (
	'pre::before' => [
		'radial-gradient(circle, var(--wm-title-fg) 4.5px, transparent 4.5px)'
		    . ' 4px 4px / 12px 12px no-repeat',
		"$bg 4px 4px / 12px 12px no-repeat",
		"$fg 3px 3px / 14px 14px no-repeat",
		'var(--wm-title-bg)',
	],
	'pre::after' => [
		"$fg right 11px top 4px / 1px 5px no-repeat",
		"$fg right 11px top 8px / 5px 1px no-repeat",
		"$fg right 7px top 4px / 1px 9px no-repeat",
		"$fg right 7px top 12px / 9px 1px no-repeat",
		"$bg right 4px top 4px / 12px 12px no-repeat",
		"$fg right 3px top 3px / 14px 14px no-repeat",
		'conic-gradient(var(--wm-title-fg) 25%, var(--wm-title-bg) 0 50%, '
		    . 'var(--wm-title-fg) 0 75%, var(--wm-title-bg) 0)'
		    . ' 0 0 / 2px 2px content-box',
		"$bg padding-box",
	],
);
for my $selector ( sort keys %bar ) {
	is( value( $plain, $selector, 'background' ),
		join( ', ', @{ $bar{$selector} } ),
		"$selector draws the layers of twm, in order" );
}

# WEB-STYLE-10 and WEB-STYLE-11 give the face and the line height of
# each element that names its language, in a rule of :where([lang]).
# The children inherit them. A rule in :where() has no weight, so the
# last language rule that matches a tag wins. A language rule holds
# [lang] alone, or a list of [lang] with one :lang() range each.
my $language_rule = qr/^\s*:where\(\s*\[lang\](?::lang\([\w*-]+\))?
    (?:\s*,\s*\[lang\]:lang\([\w*-]+\))*\s*\)\s*$/x;

# extended($range, $tag):
#	Report whether a :lang() range matches the tag. Selectors 4 names
#	the extended filtering of RFC 4647, section 3.3.2, and WebKit and
#	Firefox use it. The first subtags must match, or the range must
#	start with the wildcard. Each next subtag of the range must match
#	a later subtag of the tag, in order. The match can skip a subtag
#	of the tag, but not a singleton. The case of a subtag does not
#	count.
sub extended ( $range, $tag )
{
	my ( $first, @range ) = split /-/, lc $range;
	my ( $lead,  @tag )   = split /-/, lc $tag;
	return 0 unless $first eq '*' || $first eq $lead;
	for my $subtag ( grep { $_ ne '*' } @range ) {
		shift @tag while @tag && $tag[0] ne $subtag && length $tag[0] > 1;
		return 0 unless @tag && $tag[0] eq $subtag;
		shift @tag;
	}
	return 1;
}

# basic($range, $tag):
#	Report whether a :lang() range matches the tag by the basic
#	filtering of RFC 4647, section 3.3.1, as Chromium does. The range
#	must be the wildcard, the tag, or the start of the tag up to a
#	hyphen.
sub basic ( $range, $tag )
{
	return 1 if $range eq '*';
	return ( lc $tag ) =~ /^\Q${\ lc $range }\E(?:-|$)/ ? 1 : 0;
}

# language($text, $tag, $property, $filter):
#	The value that the language rules of the text give the property
#	on an element of the tag, or undef. A :lang() range matches by the
#	filter, extended() or basic(). A language rule with no range matches
#	each tag.
sub language ( $text, $tag, $property, $filter = \&extended )
{
	my $found;
	while ( $text =~ /([^{}]+)\{([^{}]*)\}/g ) {
		my ( $selector, $body ) = ( $1, $2 );
		next unless $selector =~ $language_rule;
		my @ranges = $selector =~ /:lang\(([\w*-]+)\)/g;
		next if @ranges && !grep { $filter->( $_, $tag ) } @ranges;
		my ($value)
		    = "$body;" =~ /(?<![-\w])\Q$property\E\s*:\s*([^;]*?)\s*;/;
		$found = $value =~ s/\s+/ /gr if defined $value;
	}
	return $found;
}

# WEB-STYLE-10 puts each stack after the Latin face, so Latin text in a
# Han page keeps Times. The sheet reaches the simplified form and the
# traditional form of Han text through each tag form of RFC 5646: a
# script subtag, a region subtag, or the bare language. A simplified
# script in a region of the traditional form keeps the simplified one.
# A script other than Latn, with no region of the traditional form,
# takes the simplified one too. The script Latn names Latin text, so it
# takes the Latin face and line height in each region.
# WebKit and Firefox match a range by extended filtering, and Chromium
# by basic filtering, so each tag takes its stack by both.
is( value( $plain, ':root', '--latin' ), '"Times New Roman", Times',
    'the Latin face is Times' );
my $latin       = 'var(--latin), serif';
my $simplified  = 'var(--latin), "Songti SC", "Noto Serif CJK SC", SimSun, serif';
my $traditional = 'var(--latin), "Songti TC", "Noto Serif CJK TC", PMingLiU, serif';
my %stack = (
	'en'         => $latin,
	'ar'         => $latin,
	'zh'         => $simplified,
	'zh-Hans'    => $simplified,
	'zh-CN'      => $simplified,
	'zh-SG'      => $simplified,
	'zh-Hans-HK' => $simplified,
	'zh-Hans-TW' => $simplified,
	'zh-Hans-MO' => $simplified,
	'zh-Latn'    => $latin,
	'zh-Latn-TW' => $latin,
	'zh-Hant'    => $traditional,
	'zh-Hant-CN' => $traditional,
	'zh-TW'      => $traditional,
	'zh-HK'      => $traditional,
	'zh-MO'      => $traditional,
);
my @filters = ( [ extended => \&extended ], [ basic => \&basic ] );
for my $tag ( sort keys %stack ) {
	for my $filter (@filters) {
		is( language( $plain, $tag, 'font-family', $filter->[1] ),
		    $stack{$tag},
		    "an element of $tag takes its stack by $filter->[0] filtering" );
	}
}

# WEB-STYLE-4 bounds the line height of Latin text, and WEB-STYLE-11
# the line height of Han text, by each filtering. A Han face has no
# italic, so Han text takes no synthetic italic.
for my $tag ( sort keys %stack ) {
	my $han = $stack{$tag} ne $latin;
	my ( $low, $high ) = $han ? ( 1.7, 1.9 ) : ( 1.5, 1.6 );
	for my $filter (@filters) {
		my $rhythm
		    = language( $plain, $tag, 'line-height', $filter->[1] );
		ok( defined $rhythm && $rhythm =~ /^[\d.]+$/
			    && $rhythm >= $low && $rhythm <= $high,
		    "the line height of $tag sits between $low and $high"
			    . " by $filter->[0] filtering" )
		    or diag 'line-height: ' . ( $rhythm // 'none' );
	}
	next unless $han;
	is( language( $plain, $tag, 'font-synthesis-style' ),
	    'none', "and $tag takes no synthetic italic" );
}

# emphasis($text, $element, $tag, $property, $filter):
#	The value that the rules of the text give the property on an em,
#	an i of the class Em or a bare i, in an element of the tag, or
#	undef. The check reads each selector of one compound: an element,
#	a class, and the :lang() and :not(:lang()) pseudo-classes. A range
#	matches by the filter. The selector of the highest specificity
#	wins, and of two equal ones the last wins.
sub emphasis ( $text, $element, $tag, $property, $filter )
{
	my ( $name, $class ) = split /\./, $element;
	my ( $found, $high ) = ( undef, -1 );
	while ( $text =~ /([^{}]+)\{([^{}]*)\}/g ) {
		my ( $list, $body ) = ( $1, $2 );
		my ($value)
		    = "$body;" =~ /(?<![-\w])\Q$property\E\s*:\s*([^;]*?)\s*;/
		    or next;
		for ( map { s/^\s+|\s+$//gr } split /,/, $list ) {
			my ( $type, $classes, $pseudo ) = /^([\w-]*)((?:\.[\w-]+)*)
			    ((?::lang\([\w*-]+\)|:not\(:lang\([\w*-]+\)\))*)$/x
			    or next;
			my @classes = $classes =~ /\.([\w-]+)/g;
			my @in      = $pseudo =~ /(?<!not\():lang\(([\w*-]+)\)/g;
			my @out     = $pseudo =~ /:not\(:lang\(([\w*-]+)\)\)/g;
			next if length $type && $type ne $name;
			next if grep { $_ ne ( $class // '' ) } @classes;
			next if grep { !$filter->( $_, $tag ) } @in;
			next if grep { $filter->( $_, $tag ) } @out;
			my $weight = 10 * ( @classes + @in + @out )
			    + ( length $type ? 1 : 0 );
			( $found, $high ) = ( $value, $weight ) if $weight >= $high;
		}
	}
	return defined $found ? $found =~ s/\s+/ /gr : undef;
}

# WEB-STYLE-11 marks emphasis in Han text with dots below each
# character. A body fragment marks emphasis with an em, and mandoc(1)
# writes the Em macro of mdoc(7) as an i of the class Em. Each takes no
# italic. mandoc(1) writes \fI of man(7), and I<> of a POD sidecar, as
# a bare i, and the check below holds its italic. The script Latn names
# Latin text, so each of the three keeps its italic and takes no dots.
# The browser gives an em and an i the italic, so a font-style that no
# rule sets is italic. Each check holds by each filtering.
my %emphasis = (
	'normal dot'  => 'no italic and the dots',
	'italic dot'  => 'the italic and the dots',
	'italic none' => 'the italic and no dots',
);
for my $tag ( sort keys %stack ) {
	my $han = $stack{$tag} ne $latin;
	for my $filter (@filters) {
		for my $element (qw(em i.Em i)) {
			my %got = map {
				$_ => emphasis( $plain, $element, $tag, $_, $filter->[1] )
			} qw(font-style text-emphasis text-emphasis-position);
			my $want
			    = !$han            ? 'italic none'
			    : $element eq 'i' ? 'italic dot'
			    :                   'normal dot';
			is( ( $got{'font-style'} // 'italic' ) . ' '
				    . ( $got{'text-emphasis'} // 'none' ),
			    $want,
			    "an $element of $tag takes $emphasis{$want}"
				    . " by $filter->[0] filtering" );
			next unless $han;
			is( $got{'text-emphasis-position'},
			    'under right', 'and it puts the dots below the text' );
		}
	}
}

# bare($list):
#	Report whether a selector of the list can match a bare i, an i
#	with no attribute, on a page of zh. The last compound of a
#	selector is the element itself. It must name i, the wildcard or no
#	element, and hold no class, id, attribute or pseudo-element. Each
#	:lang() range of it must start with zh or the wildcard. The check
#	reads no other argument of a pseudo-class, so a doubt counts as a
#	match.
sub bare ($list)
{
	( my $flat = $list ) =~ s/:lang\(\s*([\w*-]+)\s*\)/:lang=$1/g;
	$flat =~ s/\[[^\]]*\]/[]/g;
	1 while $flat =~ s/\([^()]*\)//g;
	for ( split /,/, $flat ) {
		my ($subject) = /([^\s>+~]*)\s*$/;
		next if $subject =~ /::|[.#\[]/;
		next if $subject =~ /^([\w-]+)/ && $1 ne 'i';
		my @ranges = $subject =~ /:lang=([\w*-]+)/g;
		next if grep { !/^(?:zh|\*)(?:-|$)/i } @ranges;
		return 1;
	}
	return 0;
}

# A bare i marks what the reader substitutes, per WEB-STYLE-7, so it
# keeps its italic on a page of zh. No rule that can match it takes an
# upright style. The font shorthand sets the style too, and it is
# upright when it names no italic. The rule of em and .Em matches no
# bare i, so it can take the upright style.
my @upright;
my $italic = qr/\b(?:italic|oblique)\b/;
while ( $sheet =~ /([^{}]+)\{([^{}]*)\}/g ) {
	my ( $list, $body ) = ( $1, $2 );
	$list =~ s/^\s+|\s+$//g;
	next unless bare($list);
	for ( split /;/, $body ) {
		my ( $property, $value ) = /^\s*([\w-]+)\s*:\s*(.*?)\s*$/s
		    or next;
		push @upright, "$list { $property: $value }"
		    if $property =~ /^font(?:-style)?$/ && $value !~ $italic;
	}
}
is_deeply( \@upright, [], 'no rule sets a bare i of zh upright' )
    or diag join "\n", @upright;

# The language rules carry the face and the line height of WEB-STYLE-4,
# WEB-STYLE-10 and WEB-STYLE-11. A rule of an element outranks a rule
# in :where(), so a face or a line height in another rule hides them.
# Five rules keep their own: the code face of WEB-STYLE-4, which also
# takes a path of mandoc(1), the face of a code element in a code
# element, the line height of a heading, the face of xterm and the line
# height of a pre block, and the title face of twm of WEB-STYLE-8. The
# font shorthand sets the face and the line height, so no rule takes it.
my %typeset = (
	'code, tt, kbd, samp, var, .Pa' => ['font-family'],
	':is(code, pre, tt, kbd, samp, var, .Pa) :is(code, tt, kbd, samp, var, .Pa)'
	    => ['font-family'],
	'h1, h2, h3, h4, h5, h6' => ['line-height'],
	'pre'                    => [ 'font-family', 'line-height' ],
	'pre::before'            => ['font-family'],
);
my @typeset;
while ( $sheet =~ /([^{}]+)\{([^{}]*)\}/g ) {
	my ( $list, $body ) = ( $1, $2 );
	next if $list =~ $language_rule;
	$list = join ', ', map { s/^\s+|\s+$//gr } split /,/, $list;
	for ( split /;/, $body ) {
		my ($property) = /^\s*([\w-]+)\s*:/ or next;
		push @typeset, "$list { $property }"
		    if $property =~ /^(?:font|font-family|line-height)$/
		    && !grep { $_ eq $property } @{ $typeset{$list} // [] };
	}
}
is_deeply( \@typeset, [], 'no other rule sets a face or a line height' )
    or diag join "\n", @typeset;

# WEB-STYLE-12 mirrors a page of dir="rtl", so no property names a
# side of the box. A physical property has a side in its name: top,
# right, bottom or left. A float, a clear and a text alignment must
# not take left or right. A box shorthand of more than one value sets
# each side in turn, so it takes one value alone.
my @physical;
while ( $sheet =~ /([^{}]+)\{([^{}]*)\}/g ) {
	for ( split /;/, $2 ) {
		my ( $property, $value ) = /^\s*([\w-]+)\s*:\s*(.*?)\s*$/s
		    or next;
		( my $words = $value ) =~ s/\s+/ /g;
		1 while $words =~ s/\([^()]*\)//g;
		my $count = () = $words =~ /\S+/g;
		push @physical, "$property: $value"
		    if $property =~ /(?:^|-)(?:top|right|bottom|left)(?:-|$)/
		    || $property =~ /^(?:float|clear|text-align(?:-last)?)$/
		    && $value =~ /\b(?:left|right)\b/
		    || $property
		    =~ /^(?:margin|padding|inset|border-(?:width|style|color|radius))$/
		    && $count > 1;
	}
}
is_deeply( \@physical, [], 'no property names a side of the box' )
    or diag join "\n", @physical;

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
# line. WEB-STYLE-8 needs the dark text of the default xterm on a light
# ground in the light scheme, and light text on a dark ground in the
# dark scheme. The light :root block comes first. The dark block
# overrides it, so each block reads over the values of the blocks
# before it.
my @terminal = ( [qw(--term-fg --term-bg)], [qw(--term-bg --term-fg)] );
my %scheme;
$block = 0;
for my $root ( $sheet =~ /:root\s*\{([^}]*)\}/g ) {
	$block++;
	%scheme = ( %scheme, "$root;" =~ /(--[\w-]+)\s*:\s*([^;]*?)\s*;/g );
	for my $pair ( [qw(--shadow --highlight)], $terminal[ $block - 1 ] ) {
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

# WEB-MANUALS-9 to WEB-MANUALS-11 over the manual and a sidecar of this
# repository. Each page opens with its title, holds no head and no foot
# of mandoc(1), holds each section heading as an h2 with no link to
# itself, and holds each character outside ASCII as text.
my %manual = (
	'en/fuguweb.1.html'               => 'fuguweb(1)',
	'en/App::FuguWeb::Fragment.3p.html' => 'App::FuguWeb::Fragment(3p)',
);
for my $page ( sort keys %manual ) {
	my $html = Fugu::File->read("$out/$page") // '';
	like( $html, qr{<main>\n<h1>\Q$manual{$page}\E</h1>\n},
		"$page opens with its title" );
	unlike( $html, qr{class="(?:head|foot)\b},
		"$page holds no head and no foot of mandoc" );
	like( $html, qr{<h2 class="Sh" id="NAME">NAME</h2>},
		"$page holds a section heading as an h2" );
	unlike( $html, qr{<h1 class=}, "$page holds no section heading as an h1" );
	unlike( $html, qr{<h[1-6][^>]*><a class="permalink"},
		"$page holds no heading that links itself" );
	unlike( $html, qr{&#x}, "$page holds no character reference" );
}
like( Fugu::File->read("$out/en/fuguweb.1.html") // '',
	qr{<code class="Nm">fuguweb</code> \xe2\x80\x94},
	'the dash of the name line is text' );

ok( site()->build, 'a second build succeeds over the same tree' );

ok( site()->clean, 'the clean takes the default output' );
ok( !-e $out, 'and the tree is gone' );

ok( -f "$root/.fuguwebrc",         'the description is untouched' );
ok( -d "$root/web",                'and the source directory' );
ok( -f "$root/web/index.body.html", 'and its files' );

done_testing();
