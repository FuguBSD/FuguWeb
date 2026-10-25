# ex:ts=8 sw=4:
# $OpenBSD$
#
# Copyright (c) 2026 Dick Olsson <hi@senzilla.io>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

use v5.36;

package App::FuguWeb::Check;

use App::FuguWeb;
use App::FuguWeb::Keys;
use Fugu::File;

# App::FuguWeb::Check - what a built site must be true of.
#
# The checks are generic, so every project that uses the tool gets
# them. A project keeps only the assertions that are about its own
# content.
#
# The class never fetches a link. It collects the external ones and
# reports them, because the build and its checks touch no network.

# App::FuguWeb::Check->new(%args):
#	config => $config	the site description (required)
#	out    => $dir		the built site (required)
sub new ( $class, %args )
{
	my $config = $args{config};
	die 'config parameter required'
	    unless defined $config;
	die 'out parameter required'
	    unless defined $args{out};

	return bless {
		config   => $config,
		out      => $args{out},
		external => {},
	}, $class;
}

# $self->pages:
#	Every page of every language tree, in a stable order: for each
#	language, the pages of the description, then one page for each
#	manual. Each name is <path>/<page>, where the path is that of
#	the tree of the language.
sub pages ($self)
{
	my $config = $self->{config};
	my @names  = $config->page_names;

	return map {
		my $path = $_->path;
		map { "$path/$_" } @names
	} $config->languages;
}

# $self->generated_pages:
#	The human page of each key directory. The build writes it
#	itself, and no description block names it. The pages of the
#	top level are the other pages outside every tree, and
#	top_pages of the description names them.
#
#	The page gets the checks of a page, so a broken link of the
#	chrome fails the check. It gets no reachability check: the
#	site links the key directory when it wants to, and a site that
#	does not is not broken.
sub generated_pages ($self)
{
	return grep { m{\.html\z} } $self->{config}->key_paths;
}

# $self->external:
#	The external links that the last run collected, sorted. The
#	class never fetches one.
sub external ($self)
{
	my @links = sort keys %{ $self->{external} };

	return @links;
}

# $self->run:
#	Check the site and return the problems, each one a sentence
#	that names the page. An empty list means the site is good.
#
#	Each page of a tree, each page of the top level and the human
#	page of each key directory take the checks of a page. The place
#	of the path of a page decides its chrome, as it does in
#	App::FuguWeb::Page. The forward takes the checks of its own
#	shape.
sub run ($self)
{
	$self->{external}  = {};
	$self->{inventory} = { map { $_ => 1 } $self->{config}->inventory };

	my @problems = $self->_check_inventory;

	my $forward   = App::FuguWeb::FORWARD_PAGE;
	my @not_found = grep { $_ ne $forward } $self->{config}->top_pages;

	for my $page ( $self->pages, @not_found, $self->generated_pages ) {
		next unless -f $self->{out} . "/$page";
		push @problems, $self->_check_page($page);
	}

	push @problems, $self->_check_forward
	    if -f $self->{out} . "/$forward";
	push @problems, $self->_check_nav;
	push @problems, $self->_check_reachable;
	push @problems, $self->_check_keys;

	return @problems;
}

# $self->_check_keys:
#	Hold each key directory to the design. A description with no
#	keys block has no key directory, and the checks then find
#	nothing to say.
#
#	The rules read the source directory and not the output, so the
#	answer does not depend on a build having run. A stray key file
#	and a stale digest are faults of the checkout.
sub _check_keys ($self)
{
	my $config = $self->{config};

	return map {
		App::FuguWeb::Keys->new( config => $config, dir => $_ )
		    ->problems
	} $config->keys_dirs;
}

# $self->_check_inventory:
#	Every page and asset exists and is not empty, and the output
#	holds nothing else: no staging directory, no editor backup, no
#	stray source.
sub _check_inventory ($self)
{
	my @problems;

	unless ( -d $self->{out} ) {
		return "$self->{out}: the site is not built";
	}

	my @expected = $self->{config}->inventory;
	for my $name (@expected) {
		my $path = $self->{out} . "/$name";
		push @problems, "$name: missing from the output"
		    unless -e $path;
		push @problems, "$name: empty" if -e $path && !-s $path;
	}

	# The walk reads the whole tree. Each language tree and each
	# key directory sit below the top level, and a walk of one
	# level would take every page and every key for a stray file.
	my $entries = App::FuguWeb::list_tree( $self->{out} )
	    or return "$self->{out}: cannot read the output directory: $!";

	my %expected = map { $_ => 1 } @expected;
	push @problems, "$_: in the output but not in the site"
	    for grep { !$expected{$_} } @$entries;

	return @problems;
}

# An href of the description that passes unchanged, per WEB-LINKS-2: an
# absolute URL, and a root-absolute path, which the check of the
# references refuses, per WEB-LINKS-4.
my $UNCHANGED = qr{\A(?:[A-Za-z][A-Za-z0-9.+-]*:|/)};

# $self->_check_nav:
#	Hold each relative nav href of the description to a page of
#	each tree, per WEB-LINKS-2. The path of the href resolves from
#	each tree, and it must name a page of that tree.
sub _check_nav ($self)
{
	my $config = $self->{config};
	my @names  = $config->page_names;
	my %tree   = map {
		my $path = $_->path;
		( $path => { map { ( "$path/$_" => 1 ) } @names } )
	} $config->languages;

	my @problems;
	for my $href ( map { $_->{href} } $config->nav ) {
		next if $href =~ $UNCHANGED;

		my ($path) = App::FuguWeb::ref_parts($href);
		push @problems,
		    map { qq{nav "$href": names no page of the tree $_} }
		    grep {
			!$tree{$_}{ App::FuguWeb::resolve_ref( $_, $path )
				    // '' }
		    }
		    sort keys %tree;
	}

	return @problems;
}

# $self->_check_page($page):
#	Everything that one page must be true of. A page of a tree
#	takes the chrome of its tree. A page of the top level and the
#	human page of a key directory take the chrome of the default
#	tree, and a page of the top level carries the base.
sub _check_page ( $self, $page )
{
	my $html = Fugu::File->read( $self->{out} . "/$page" ) // '';
	my @problems;

	my ($title) = $html =~ m{<title>([^<]*)</title>};
	push @problems, "$page: has no title"
	    unless defined $title && length $title;

	# WEB-LANGUAGE-13. A tree page carries the tag and the
	# direction of its tree on its html element.
	my $tree = $self->_tree_of($page);
	if ($tree) {
		my $element = '<html' . $tree->attributes . '>';
		push @problems, "$page: does not carry $element"
		    unless index( $html, $element ) >= 0;
	}

	push @problems, $self->_check_head( $page, $html, $tree );
	push @problems, $self->_check_chrome( $page, $html, $tree );

	# The links of WEB-CHROME-6 name the site by its url, and the
	# check of the head holds each one. None of them is an
	# external link. A link of the body is no link of the head, so
	# the check of the references holds it.
	$html =~ s{(<head>.*?</head>)}
	    {$1 =~ s{<link rel="(?:canonical|alternate)"[^>]*>}{}gr}se;

	# WEB-LINKS-4. The base of a page of the top level is the one
	# root-absolute href of the site. The check takes it out, so
	# every other root-absolute href still fails. Each relative
	# reference of the page then resolves from the base, which is
	# the site root, per WEB-LINKS-3.
	my $base;
	if ( $page !~ m{/} ) {
		my $element =
		      '<base href="'
		    . App::FuguWeb::escape_attr( $self->{config}->url_path )
		    . '">';
		my $at = index $html, $element;
		if ( $at < 0 ) {
			push @problems, "$page: does not carry $element";
		}
		else {
			substr( $html, $at, length $element ) = '';
			$base = '';
		}
	}

	push @problems, $self->_check_references( $page, $html, $base );

	return @problems;
}

# $self->_tree_of($page):
#	The language of the tree that holds one page of the output, or
#	undef for a page outside every tree. A page of a tree is one
#	segment below the path of the tree.
sub _tree_of ( $self, $page )
{
	my ( $path, $name, @deeper ) = split m{/}, $page;
	return if !defined $name || @deeper;

	my ($language) =
	    grep { $_->path eq $path } $self->{config}->languages;

	return $language;
}

# $self->_check_head($page, $html, $tree):
#	Hold the links of WEB-CHROME-6 in the head of a page. A tree
#	page links itself, the same page in each language, and the
#	forward page. Any other page links none. Each href is the url
#	of the site, then the path of a page of the inventory, or the
#	bare url, per WEB-LINKS-5.
sub _check_head ( $self, $page, $html, $tree )
{
	my $url = $self->{config}->url;

	my ($head) = $html =~ m{<head>(.*?)</head>}s;
	my @held =
	    ( $head // '' ) =~ m{(<link rel="(?:canonical|alternate)"[^>]*>)}g;

	my @problems;
	for my $link (@held) {
		my ($href) = $link =~ m{\bhref="([^"]*)"};
		$href = _unescape( $href // '' );

		my $path =
		    index( $href, $url ) == 0
		    ? substr( $href, length $url )
		    : undef;
		push @problems,
		    "$page: $href is no URL of a page of the site"
		    unless defined $path
		    && (
			$path eq ''
			|| ( $path =~ m{\.html\z} && $self->{inventory}{$path} )
		    );
	}

	my @want;
	if ($tree) {
		my ( undef, $name ) = split m{/}, $page, 2;
		my $to = sub ($path) {
			return App::FuguWeb::escape_attr( $url . $path );
		};

		@want = (
			'<link rel="canonical" href="' . $to->($page) . '">',
			(
				map {
					      '<link rel="alternate" hreflang="'
					    . $_->tag
					    . '" href="'
					    . $to->( $_->path . "/$name" )
					    . '">'
				} $self->{config}->languages
			),
			'<link rel="alternate" hreflang="x-default" href="'
			    . $to->('') . '">',
		);
	}

	my %held = map { $_ => 1 } @held;
	push @problems, map { "$page: the head does not carry $_" }
	    grep { !$held{$_} } @want;
	push @problems,
	      "$page: the head carries "
	    . scalar(@held)
	    . ' canonical and alternate links, and the page takes '
	    . scalar(@want)
	    unless @held == @want;

	return @problems;
}

# $self->_check_chrome($page, $html, $tree):
#	Hold the chrome of the body of a page: the header, the list of
#	the languages and the nav, per WEB-CHROME-2 to WEB-CHROME-5. A
#	tree page takes the words of its tree. A page outside every
#	tree takes the words of the default tree, and it carries no
#	list of the languages. Each link of the chrome resolves from
#	the path of the page, per WEB-LINKS-3.
sub _check_chrome ( $self, $page, $html, $tree )
{
	my $words = $tree // $self->{config}->default_language;

	# The chrome is the page around the body fragment and the
	# footer fragment. The two fragments are the writer's own.
	my $chrome = $html;
	$chrome =~ s{(<main\b[^>]*>).*</main>}{$1</main>}s;
	$chrome =~ s{(<footer\b[^>]*>).*</footer>}{$1</footer>}s;

	my @problems;
	push @problems, "$page: the chrome carries a class"
	    if $chrome =~ m{<[^>]*\sclass=};
	push @problems, "$page: the chrome carries an hr"
	    if $chrome =~ m{<hr\b};

	# WEB-CHROME-5. Each word of the chrome of the body is the
	# text of a link. A word between two links is a separator, and
	# the sheet draws each one instead, per WEB-STYLE-9.
	my ($body) = $chrome =~ m{<body>(.*)</body>}s;
	my $loose = ( $body // '' ) =~ s{<a\b[^>]*>.*?</a>}{}gsr;
	$loose =~ s{<[^>]*>}{}g;
	push @problems, "$page: the chrome carries a text separator"
	    if $loose =~ /\S/;

	# WEB-CHROME-2. The site link comes before the list of the
	# languages.
	my ($header) = $chrome =~ m{<header\b[^>]*>(.*?)</header>}s;
	$header //= '';
	my ($lead) = $header =~ m{\A(.*?)(?:<ul\b|\z)}s;
	my ($site) = _links($lead);
	my $entry  = $words->path . '/' . $self->{config}->entry;
	push @problems, "$page: the header does not link $entry"
	    unless $site && _target( $page, $site->{href} ) eq $entry;
	push @problems, _current( $page, 'the site link', $site // {}, 0 );

	push @problems, $self->_check_languages( $page, $header, $tree );
	push @problems,
	    $self->_check_navigation( $page, $chrome, $words, $tree );

	return @problems;
}

# $self->_check_languages($page, $header, $tree):
#	Hold the list of the languages of WEB-CHROME-3. A tree page of
#	a site of more than one language holds one item for each
#	language, in the order of the declaration. The link of each
#	item goes to the same page in that language. Its text is the
#	name of the language, and the tag is its lang and its
#	hreflang. The link of the language of the page is the current
#	one. Any other page holds no item.
sub _check_languages ( $self, $page, $header, $tree )
{
	my @languages = $self->{config}->languages;
	@languages = () unless $tree && @languages > 1;

	my ($list) = $header =~ m{<ul\b[^>]*>(.*?)</ul>}s;
	my @items = _items( $list // '' );

	my @problems;
	push @problems,
	      "$page: carries "
	    . scalar(@items)
	    . ' language links, and the page takes '
	    . scalar(@languages)
	    unless @items == @languages;

	my ( undef, $name ) = split m{/}, $page, 2;
	for my $i ( 0 .. $#languages ) {
		my $language = $languages[$i];
		my $link     = $items[$i] // {};
		my $tag      = $language->tag;
		my $text     = App::FuguWeb::encode(
			App::FuguWeb::escape_html( $language->name ) );

		push @problems, "$page: does not link the page in $tag"
		    unless _target( $page, $link->{href} ) eq $language->path
		    . "/$name"
		    && ( $link->{hreflang} // '' ) eq $tag
		    && ( $link->{lang}     // '' ) eq $tag
		    && ( $link->{text}     // '' ) eq $text;

		push @problems,
		    _current( $page, "the link to $tag",
			$link, $tag eq $tree->tag );
	}

	return @problems;
}

# $self->_check_navigation($page, $chrome, $words, $tree):
#	Hold the nav of WEB-CHROME-4: one item for each nav entry of the
#	tree of the words, in the order of the description. A relative
#	href resolves from the page to the page of the tree that it
#	names. Any other href stands as the description writes it. The
#	entry whose path, with no query, resolves from the tree to the
#	page is the current one. A site with no nav entry carries no
#	nav.
sub _check_navigation ( $self, $page, $chrome, $words, $tree )
{
	my @entries = $self->{config}->nav( $words->tag );
	my ($nav) = $chrome =~ m{<nav\b[^>]*>(.*?)</nav>}s;

	unless (@entries) {
		return () unless defined $nav;
		return "$page: carries a nav, and the site has no nav entry";
	}

	my ($list) = ( $nav // '' ) =~ m{<ul\b[^>]*>(.*?)</ul>}s;
	my @items = _items( $list // '' );

	my @problems;
	push @problems,
	      "$page: carries "
	    . scalar(@items)
	    . ' navigation links, and the site has '
	    . scalar(@entries)
	    unless @items == @entries;

	for my $i ( 0 .. $#entries ) {
		my $href = $entries[$i]{href};
		my $link = $items[$i] // {};

		my $held =
		    $href =~ $UNCHANGED
		    ? _unescape( $link->{href} // '' ) eq $href
		    : _target( $page, $link->{href} ) eq
		    ( App::FuguWeb::resolve_ref( $words->path, $href ) // '' );
		push @problems,
		    "$page: does not carry the navigation entry $href"
		    unless $held;

		my ($path) = App::FuguWeb::ref_parts($href);
		my $current = $tree
		    && ( App::FuguWeb::resolve_ref( $words->path, $path )
			// '' ) eq $page;
		push @problems,
		    _current( $page, "the navigation entry $href",
			$link, $current );
	}

	return @problems;
}

# _current($page, $what, $link, $current):
#	The problem of a link that carries aria-current="page" and is
#	not the current one, or the reverse. The answer is empty when
#	the link agrees.
sub _current ( $page, $what, $link, $current )
{
	my $held = ( $link->{'aria-current'} // '' ) eq 'page';
	return () if $held == !!$current;

	return
	      "$page: $what "
	    . ( $current ? 'does not carry' : 'carries' )
	    . ' aria-current="page"';
}

# _links($html):
#	Each link of a part of a page, in order, as a hash reference of
#	its attributes, with its text under the key text.
sub _links ($html)
{
	my @links;
	while ( $html =~ m{<a\b([^>]*)>(.*?)</a>}gs ) {
		my ( $attributes, $text ) = ( $1, $2 );
		push @links,
		    {
			( $attributes =~ m{([a-z-]+)="([^"]*)"}g ),
			text => $text
		    };
	}

	return @links;
}

# _items($list):
#	The link of each item of one list, in order. An item with no
#	link gives an empty hash reference.
sub _items ($list)
{
	return
	    map { ( _links($_) )[0] // {} } $list =~ m{<li\b[^>]*>(.*?)</li>}gs;
}

# _target($page, $href):
#	The path below the site root that one href of the chrome of a
#	page names, or an empty string when it names none.
sub _target ( $page, $href )
{
	return App::FuguWeb::resolve_ref( _dir($page),
		_unescape( $href // '' ) ) // '';
}

# $self->_check_forward:
#	Hold the top-level index.html to its shape: a meta refresh to
#	the entry page of the default tree, and one link to that page
#	as its one reference. The page loads nothing and carries no
#	nav.
sub _check_forward ($self)
{
	my $page = App::FuguWeb::FORWARD_PAGE;
	my $html = Fugu::File->read( $self->{out} . "/$page" ) // '';
	my $to   = App::FuguWeb::escape_attr(
		      $self->{config}->default_language->path . '/'
		    . $self->{config}->entry );

	my @problems;

	push @problems, "$page: does not forward to $to"
	    unless
	    index( $html, qq{<meta http-equiv="refresh" content="0; url=$to">} )
	    >= 0;

	# One reference, and that one the link to the entry page. A
	# second href or any src is a thing that the page loads, or a
	# second way out of it.
	my @refs = $html =~ m{(?:href|src)="([^"]+)"}g;
	push @problems, "$page: holds a reference other than one link to $to"
	    unless @refs == 1
	    && index( $html, qq{<a href="$to">} ) >= 0;

	push @problems, "$page: carries a nav, and the forward takes none"
	    if $html =~ m{<nav\b};

	push @problems, $self->_check_references( $page, $html, undef );

	return @problems;
}

# $self->_check_references($page, $html, $base):
#	Every href and src of one page. A relative reference resolves
#	against the directory of the page. It resolves against the base
#	when the page holds one, and the base is then the directory
#	below the site root that it names, per WEB-LINKS-3.
sub _check_references ( $self, $page, $html, $base )
{
	my @problems;

	for my $ref ( map { _unescape($_) }
		$html =~ m{(?:href|src)="([^"]+)"}g )
	{

		# The host may serve the site from a path below the
		# root, where a leading slash leaves the site entirely.
		if ( $ref =~ m{^/} ) {
			push @problems, "$page: $ref is root-absolute";
			next;
		}
		if ( $ref =~ m{^file:}i ) {
			push @problems, "$page: $ref is a file: URL";
			next;
		}
		if ( $ref =~ m{^https?://} ) {
			$self->{external}{$ref} = 1;
			next;
		}
		next if $ref =~ m{^(?:mailto|news|ftp):}i;

		# A browser reads a relative URL whose first segment
		# holds a colon as a scheme, so a page named
		# Fugu::Daemon.3p.html needs its './'.
		if ( $ref =~ /^[A-Za-z][A-Za-z0-9.+-]*:/ ) {
			push @problems, "$page: $ref reads as a URL scheme;"
			    . ' a local link needs its ./';
			next;
		}

		# A fragment alone names the page itself, or the base
		# when the page holds one. A base names a directory,
		# and a directory is no page.
		my ( $path, $fragment ) = App::FuguWeb::ref_parts($ref);
		if ( length $path ) {
			$path = App::FuguWeb::resolve_ref( $base // _dir($page),
				$path );
		}
		else {
			$path = defined $base ? undef : $page;
		}
		unless ( defined $path ) {
			push @problems, "$page: $ref names no page of the site";
			next;
		}

		# The target is a file of the inventory. A file that the
		# inventory does not name is a stray, and a directory is
		# no file.
		unless ( $self->{inventory}{$path}
			&& -f $self->{out} . "/$path" )
		{
			push @problems, "$page: $ref leads nowhere";
			next;
		}
		next unless defined $fragment && length $fragment;

		my $target = Fugu::File->read( $self->{out} . "/$path" ) // '';
		push @problems, "$page: $ref has no such anchor"
		    unless $target =~ /\bid="\Q$fragment\E"/;
	}

	return @problems;
}

# _dir($page):
#	The directory of one page, as a path below the site root: a
#	language tree, a key directory, or the empty path of the top
#	level.
sub _dir ($page)
{
	return $page =~ s{/?[^/]*\z}{}r;
}

# _unescape($text):
#	Turn the four attribute entities back into their characters. A
#	reference is compared against a file name, and the file holds
#	the character and not the entity.
sub _unescape ($text)
{
	my $plain = $text;
	$plain =~ s/&lt;/</g;
	$plain =~ s/&gt;/>/g;
	$plain =~ s/&quot;/"/g;
	$plain =~ s/&amp;/&/g;

	return $plain;
}

# $self->_check_reachable:
#	Every page of each tree is reachable from the entry page of
#	that tree, per WEB-LANGUAGE-13. A page that no other page links
#	to declares itself unlinked, as a 404 page does: the host
#	serves that one for an unknown path.
#
#	The pages of the top level take no walk. The forward leads
#	into the default tree, and the copy of the 404 page answers a
#	path that no page links to.
sub _check_reachable ($self)
{
	my $config = $self->{config};

	my %unlinked = map { $_->{file} => 1 }
	    grep { $_->{unlinked} } $config->pages;

	my @problems;
	for my $tree ( map { $_->path } $config->languages ) {
		my $entry = "$tree/" . $config->entry;
		unless ( -f $self->{out} . "/$entry" ) {
			push @problems, "$entry: the entry page is missing";
			next;
		}

		my $seen = $self->_walk( $tree, $entry );

		push @problems, map { "$tree/$_: no page links to it" }
		    grep { !$seen->{"$tree/$_"} && !$unlinked{$_} }
		    $config->page_names;
	}

	return @problems;
}

# $self->_walk($tree, $entry):
#	Every path that the tree reaches from its entry page, as a hash
#	reference. The tree is the path of the tree below the output.
#	The walk stays inside the tree, so a link into another tree
#	reaches no page of this one.
sub _walk ( $self, $tree, $entry )
{
	my %seen  = ( $entry => 1 );
	my @queue = ($entry);

	while ( my $page = shift @queue ) {
		next unless $page =~ /\.html$/;

		my $html = Fugu::File->read( $self->{out} . "/$page" ) // '';
		for my $ref ( map { _unescape($_) }
			$html =~ m{(?:href|src)="([^"]+)"}g )
		{
			next if $ref =~ m{^[A-Za-z][A-Za-z0-9.+-]*:};

			my ($path) = App::FuguWeb::ref_parts($ref);
			next unless length $path;
			$path = App::FuguWeb::resolve_ref( _dir($page), $path );
			next unless defined $path;
			next unless App::FuguWeb::path_below( $path, $tree );

			next if $seen{$path}++;
			push @queue, $path;
		}
	}

	return \%seen;
}

1;
