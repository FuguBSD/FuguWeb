#!/usr/bin/env perl
# ex:ts=8 sw=4:
# App::FuguWeb::Page: the chrome of each kind of page, the two
# separators, the escaping, the optional footer fragment, the language
# links, the lang and the dir of each page, and the marks of each part
# of another language.
#
# The test builds each site in a File::Temp directory. It never reads
# the repository, so a change to web/ cannot break it.

use v5.36;
use Test::More;
use FindBin qw($RealBin);
use lib "$RealBin/../../lib";
use File::Path qw(make_path);
use File::Temp qw(tempdir);

use_ok('App::FuguWeb::Config');
use_ok('App::FuguWeb::Page');

# site($rc, %files):
#	Build a project with the description $rc and the named files
#	in its source directory. Return the loaded configuration.
sub site ( $rc, %files )
{
	my $root = tempdir( CLEANUP => 1 );
	open my $fh, '>', "$root/.fuguwebrc"
	    or die "Cannot write the description: $!";
	print {$fh} $rc;
	close $fh;

	make_path("$root/web");
	for my $name ( sort keys %files ) {
		make_path( "$root/web/$name" =~ s{/[^/]+\z}{}r );
		open my $out, '>', "$root/web/$name"
		    or die "Cannot write $name: $!";
		print {$out} $files{$name};
		close $out;
	}

	my $config =
	    App::FuguWeb::Config->load( root => $root, error => \my $reason );
	die "$reason\n" unless $config;

	return $config;
}

# render($page, $title, $fragment, %page):
#	Write one page into a scratch file and return its bytes.
#	write is the one public method, so the test reads back what
#	it wrote. The page arguments go to write as they stand.
sub render ( $page, $title, $fragment, %page )
{
	my $path = tempdir( CLEANUP => 1 ) . '/page.html';
	$page->write( $path, $title, $fragment, %page )
	    or die 'write failed';

	open my $fh, '<', $path or die "Cannot read $path: $!";
	binmode $fh;
	local $/ = undef;
	my $html = <$fh>;
	close $fh;

	return $html;
}

my $RC = <<'RC';
site = Example
url  = https://example.org/

nav "index.html" {
	label = Home
}

nav "manuals.html" {
	label = Manuals
}
RC

subtest 'the whole chrome of a tree page, in order' => sub {
	my $page = App::FuguWeb::Page->new( config => site($RC) );
	my $html = render( $page, 'Install', "<h1>Install</h1>\n" );

	# A tree page links each page of its own tree by name, and the
	# stylesheet at the top level, one step up.
	my $expected = <<"HTML";
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Install \xe2\x80\x94 Example</title>
<link rel="stylesheet" href="../style.css">
</head>
<body>
<header><a href="index.html">Example</a></header>
<nav>
<a href="index.html">Home</a> \xc2\xb7
<a href="manuals.html">Manuals</a>
</nav>
<hr>
<main>
<h1>Install</h1>
</main>
</body>
</html>
HTML

	is( $html, $expected, 'the page is byte for byte the chrome' );

	# WEB-LANGUAGE-10. The html element carries the tag of the tree,
	# and dir="rtl" for a language that is right to left.
	my $config = site( $RC . <<'RC' );

language en {
	name = English
}

language sv {
	name = Svenska
}

language ar {
	name = Arabic
	dir  = rtl
}
RC
	$page = App::FuguWeb::Page->new(
		config   => $config,
		language => $config->language('sv')
	);
	like( render( $page, 'Install', '', name => 'install.html' ),
		qr/<html lang="sv">\n/,
		'the html element carries the tag of the tree' );

	$page = App::FuguWeb::Page->new(
		config   => $config,
		language => $config->language('ar')
	);
	like( render( $page, 'Install', '', name => 'install.html' ),
		qr/<html lang="ar" dir="rtl">\n/,
		'and dir="rtl" for a tree that is right to left' );
};

subtest 'the whole chrome of the key page, in order' => sub {
	my $page = App::FuguWeb::Page->new( config => site($RC), kind => 'keys' );
	my $html = render( $page, 'Keys', "<h1>Keys</h1>\n" );

	# The key page sits one directory below the top level, and
	# links the default tree.
	my $expected = <<"HTML";
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Keys \xe2\x80\x94 Example</title>
<link rel="stylesheet" href="../style.css">
</head>
<body>
<header><a href="../en/index.html">Example</a></header>
<nav>
<a href="../en/index.html">Home</a> \xc2\xb7
<a href="../en/manuals.html">Manuals</a>
</nav>
<hr>
<main>
<h1>Keys</h1>
</main>
</body>
</html>
HTML

	is( $html, $expected, 'the page is byte for byte the chrome' );
};

subtest 'the key page is a page of en' => sub {
	# WEB-CHROME-8. The chrome takes the words of the default
	# language, and each part of it carries the marks of that
	# language when it is not en.
	my $config = site( <<"RC" );
site = Example
url  = https://example.org/

language zh-Hans {
	name = \xe7\xae\x80\xe4\xbd\x93\xe4\xb8\xad\xe6\x96\x87
	site = \xe7\xa4\xba\xe4\xbe\x8b
}

language en {
	name = English
}

nav "index.html" {
	label = \xe9\xa6\x96\xe9\xa1\xb5
}
RC
	my $page = App::FuguWeb::Page->new( config => $config, kind => 'keys' );
	my $html = render( $page, 'Keys', "<h1>Keys</h1>\n" );

	like( $html, qr{<html lang="en">\n}, 'the page is a page of en' );
	like(
		$html,
qr{<header><a href="\.\./zh-hans/index\.html" lang="zh-Hans">\xe7\xa4\xba\xe4\xbe\x8b</a></header>},
		'its site link goes into the default tree, with its marks'
	);
	like(
		$html,
		qr{<a href="\.\./zh-hans/index\.html" lang="zh-Hans">\xe9\xa6\x96\xe9\xa1\xb5</a>},
		'and so does each nav link'
	);
	like( $html, qr{<main>\n<h1>Keys</h1>}, 'the body of en takes none' );

	# A default language that is right to left gives each mark its
	# direction too.
	$config = site( <<'RC' );
site = Example
url  = https://example.org/

language ar {
	name = Arabic
	dir  = rtl
}

nav "index.html" {
	label = Home
}
RC
	$page = App::FuguWeb::Page->new( config => $config, kind => 'keys' );
	$html = render( $page, 'Keys', '' );
	like( $html, qr{<html lang="en">\n}, 'a page of en, left to right' );
	like( $html,
		qr{<header><a href="\.\./ar/index\.html" lang="ar" dir="rtl">},
		'with the marks of ar on the site link' );
	like( $html, qr{<a href="\.\./ar/index\.html" lang="ar" dir="rtl">Home},
		'and on each nav link' );
};

subtest 'the whole chrome of the top-level 404 page, in order' => sub {
	my $page = App::FuguWeb::Page->new( config => site($RC), kind => 'top' );
	my $html = render( $page, 'Not found', "<h1>Not found</h1>\n" );

	# The host serves the copy at any path. The base makes each
	# relative link resolve from the root.
	my $expected = <<"HTML";
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<base href="/">
<title>Not found \xe2\x80\x94 Example</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<header><a href="en/index.html">Example</a></header>
<nav>
<a href="en/index.html">Home</a> \xc2\xb7
<a href="en/manuals.html">Manuals</a>
</nav>
<hr>
<main>
<h1>Not found</h1>
</main>
</body>
</html>
HTML

	is( $html, $expected, 'the page is byte for byte the chrome' );
};

subtest 'an absolute URL passes unchanged' => sub {
	my $config = site( <<'RC' );
site = Example
url  = https://example.org/

nav "https://example.org/" {
	label = Away
}
RC

	# A step in front of it would name a page that the site does not
	# hold.
	for my $kind (qw(tree keys top)) {
		my $page = App::FuguWeb::Page->new( config => $config, kind => $kind );
		like( render( $page, 'Install', '' ),
			qr{<a href="https://example\.org/">Away</a>},
			"an absolute URL on a $kind page" );
	}
};

subtest 'an unknown kind of page is a programming error' => sub {
	ok( !eval { App::FuguWeb::Page->new( config => site($RC), kind => 'x' ) },
		'the constructor dies' );
	like( $@, qr/unknown kind of page: x/, 'and names the kind' );
};

subtest 'the two separators reach the page as UTF-8' => sub {
	is( App::FuguWeb::Page::EM_DASH(),    "\x{2014}", 'the em dash' );
	is( App::FuguWeb::Page::MIDDLE_DOT(), "\x{b7}",   'the middle dot' );

	my $page = App::FuguWeb::Page->new( config => site($RC) );
	my $html = render( $page, 'Install', '' );

	like( $html, qr/<title>Install \xe2\x80\x94 Example<\/title>/,
		'an em dash separates the title from the site' );
	like( $html, qr/<\/a> \xc2\xb7\n/,
		'a middle dot separates two navigation entries' );
	unlike( $html, qr/<\/a> \xc2\xb7\n<\/nav>/,
		'the last entry carries no separator' );
};

subtest 'the title and the labels are escaped' => sub {
	my $config = site( <<'RC' );
site = A & B
url  = https://example.org/

nav "index.html" {
	label = <Home>
}
RC
	my $page = App::FuguWeb::Page->new( config => $config );
	my $html = render( $page, 'Tags < & >', '' );

	like( $html, qr/<title>Tags &lt; &amp; &gt; /,
		'the title is escaped' );
	like( $html, qr/&amp; B<\/title>/, 'the site name is escaped' );
	like( $html, qr/>&lt;Home&gt;<\/a>/, 'a navigation label is escaped' );

	# The shell chrome that this replaced substituted the title with
	# sed. A slash ended the substitution and an ampersand meant
	# "the whole match", so neither could ever reach a page.
	$html = render( $page, 'openhapd.conf(5) / 8', '' );
	like( $html, qr{<title>openhapd\.conf\(5\) / 8 },
		'a title may hold a slash' );
};

subtest 'a value that reaches an attribute is escaped' => sub {
	my $config = site( <<'RC' );
site  = Example
url   = https://example.org/
entry = index.html?a&b" onload="x

nav "search.html?q=1&r=2" {
	label = Search
}
RC
	my $page = App::FuguWeb::Page->new( config => $config );
	my $html = render( $page, 'Install', '' );

	# A quote in a value would end the attribute early, and
	# everything after it would become markup.
	like( $html, qr/href="index\.html\?a&amp;b&quot; onload=&quot;x"/,
		'a quote in the header href is escaped' );
	unlike( $html, qr/onload="x"/, 'no attribute was injected' );

	# An ampersand is not markup, but it is not valid in an
	# attribute either, and the same escape covers both.
	like( $html, qr{href="search\.html\?q=1&amp;r=2"},
		'a navigation href is escaped' );
};

subtest 'the footer fragment is optional' => sub {
	my $page = App::FuguWeb::Page->new( config => site($RC) );
	my $html = render( $page, 'Install', '' );
	unlike( $html, qr/<footer>/, 'no fragment, no footer element' );
	like( $html, qr/<\/main>\n<\/body>/, 'and no rule before one' );

	my $config = site($RC);
	$page = App::FuguWeb::Page->new(
		config => $config,
		footer => "<p>ISC.</p>\n"
	);
	$html = render( $page, 'Install', '' );
	like( $html, qr{</main>\n<hr>\n<footer>\n<p>ISC\.</p>\n</footer>\n},
		'the fragment becomes the footer of a tree page' );

	# WEB-KEYS-32. A relative link of the fragment resolves inside a
	# tree, and nowhere else.
	for my $kind (qw(keys top)) {
		$page = App::FuguWeb::Page->new(
			config => $config,
			kind   => $kind,
			footer => "<p>ISC.</p>\n"
		);
		unlike( render( $page, 'Install', '' ), qr/<footer>/,
			"a $kind page carries no footer" );
	}
};

# The description of a site of three languages. The tree of zh-Hans
# takes the path zh-hans, and the language ar is right to left.
my $LANGUAGES = $RC . <<"RC";

language en {
	name = English
}

language zh-Hans {
	name   = \xe7\xae\x80\xe4\xbd\x93\xe4\xb8\xad\xe6\x96\x87
	site   = \xe7\xa4\xba\xe4\xbe\x8b
	footer = zh-hans/footer.body.html
}

language ar {
	name = Arabic
	dir  = rtl
}

nav zh-Hans "index.html" {
	label = \xe9\xa6\x96\xe9\xa1\xb5
}
RC

subtest 'a tree page links the same page in each other language' => sub {
	my $config = site($LANGUAGES);

	# The tag is the text and the hreflang of each link, and the
	# link goes to the tree of the language. The links follow the
	# nav entries in one row.
	my $page = App::FuguWeb::Page->new( config => $config );
	like( render( $page, 'Install', '', name => 'install.html' ),
		qr{<nav>
<a href="index\.html">Home</a> \xc2\xb7
<a href="manuals\.html">Manuals</a> \xc2\xb7
<a href="\.\./zh-hans/install\.html" hreflang="zh-Hans">zh-Hans</a> \xc2\xb7
<a href="\.\./ar/install\.html" hreflang="ar">ar</a>
</nav>
}, 'a page of en links zh-Hans and ar' );

	# A module page holds a colon in its name, and the step in
	# front of it keeps the link from reading as a scheme.
	$page = App::FuguWeb::Page->new(
		config   => $config,
		language => $config->language('zh-Hans')
	);
	like( render( $page, 'Thing', '', name => 'App::Thing.3p.html' ),
		qr{<a href="\.\./en/App::Thing\.3p\.html" hreflang="en">en</a>},
		'the link names the page as the tree names it' );

	# A page outside every tree carries no language link.
	for my $kind (qw(keys top)) {
		$page = App::FuguWeb::Page->new( config => $config, kind => $kind );
		unlike( render( $page, 'Keys', '' ), qr/hreflang/,
			"a $kind page carries no language link" );
	}

	$page = App::FuguWeb::Page->new( config => $config );
	ok( !eval { render( $page, 'Install', '' ) },
		'a tree page with no name dies' );
	like( $@, qr/name parameter required/, 'and says why' );

	# A site of one language carries no language link, and needs
	# no name.
	$page = App::FuguWeb::Page->new( config => site($RC) );
	unlike( render( $page, 'Install', '' ), qr/hreflang/,
		'a site of one language links no other' );
};

subtest 'each part of another language carries its marks' => sub {
	my $config = site($LANGUAGES);

	# WEB-LANGUAGE-11. A page of zh-Hans takes its own site name and
	# its own label, and the default label of the other entry.
	my $page = App::FuguWeb::Page->new(
		config   => $config,
		language => $config->language('zh-Hans'),
		footer   => "<p>ISC.</p>\n",
	);
	my $html = render(
		$page, 'Install', "<p>Words.</p>\n",
		name      => 'install.html',
		body_lang => 'en'
	);
	like( $html, qr{<html lang="zh-Hans">\n}, 'a page of zh-Hans' );
	like(
		$html,
		qr{<header><a href="index\.html">\xe7\xa4\xba\xe4\xbe\x8b</a></header>},
		'its own site name takes no mark'
	);
	like( $html, qr{<a href="index\.html">\xe9\xa6\x96\xe9\xa1\xb5</a>},
		'nor does its own label' );
	like( $html, qr{<a href="manuals\.html" lang="en">Manuals</a>},
		'a label of en carries lang="en"' );
	like( $html, qr{<hr>\n<main lang="en">\n<p>Words\.</p>\n</main>\n},
		'and so does a body of en' );
	like( $html, qr{<footer>\n<p>ISC\.</p>\n</footer>},
		'the footer of zh-Hans takes no mark' );

	# A page of ar takes each value of en. Each mark carries the
	# direction too, because the two directions differ.
	$page = App::FuguWeb::Page->new(
		config   => $config,
		language => $config->language('ar'),
		footer   => "<p>ISC.</p>\n",
	);
	$html = render(
		$page, 'Install', "<p>Words.</p>\n",
		name      => 'install.html',
		body_lang => 'en'
	);
	like( $html, qr{<html lang="ar" dir="rtl">\n}, 'a page of ar' );
	like(
		$html,
		qr{<header><a href="index\.html" lang="en" dir="ltr">Example</a></header>},
		'the site link carries the marks of en'
	);
	like( $html, qr{<a href="index\.html" lang="en" dir="ltr">Home</a>},
		'and so does each nav link' );
	like( $html, qr{<main lang="en" dir="ltr">\n}, 'and the body' );
	like( $html, qr{<footer lang="en" dir="ltr">\n<p>ISC\.</p>\n</footer>},
		'and the footer' );

	like(
		render(
			$page, 'Install', '',
			name      => 'install.html',
			body_lang => 'ar'
		),
		qr{<hr>\n<main>\n},
		'a body of ar carries no mark'
	);
	like( render( $page, 'Install', '', name => 'install.html' ),
		qr{<hr>\n<main>\n}, 'and the body takes the language of the page' );
};

done_testing();
