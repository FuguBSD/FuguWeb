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

package App::FuguWeb::Index;

use App::FuguWeb;

# App::FuguWeb::Index - the body of the manual index.
#
# The groups follow the source directories, which is already how a
# tree is organized. Thus the index cannot drift when a manual is
# added: no list here names one.
#
# The index never retypes a description either. It asks each
# App::FuguWeb::Manual, and that reads the source. The index writes no
# prose of its own, per WEB-LANG-13: the title, the opening and each
# heading come from the description.

# App::FuguWeb::Index->new(%args):
#	config => $config	the site description (required)
#	lang   => $code		the language of the page (default: en)
sub new ( $class, %args )
{
	my $config = $args{config};
	die 'config parameter required'
	    unless defined $config;

	return bless {
		config => $config,
		lang   => $args{lang} // App::FuguWeb::DEFAULT_LANGUAGE,
	}, $class;
}

# $self->body($title, $opening):
#	The body fragment of the index page: the title as its heading,
#	then the opening, then each group, per WEB-MANUALS-8. The
#	caller passes the title and the opening of the page block in
#	the language of the page, so the heading and the browser tab
#	always agree. A page with no opening passes undef.
sub body ( $self, $title, $opening = undef )
{
	my $html = '<h1>' . App::FuguWeb::escape_html($title) . "</h1>\n\n";
	$html .= "$opening\n" if defined $opening && length $opening;
	$html .= $self->_group($_) for $self->{config}->groups;

	return $html;
}

# $self->_group($group):
#	One heading and one description list. A group with no manual
#	emits nothing, so an empty group leaves no heading behind.
sub _group ( $self, $group )
{
	my @manuals = $group->manuals( $self->{lang} );
	return '' unless @manuals;

	my $html =
	      '<h2 id="'
	    . App::FuguWeb::escape_attr( $group->name ) . '">'
	    . App::FuguWeb::escape_html( $group->heading( $self->{lang} ) )
	    . "</h2>\n<dl>\n";
	$html .= _entry($_) for @manuals;
	$html .= "</dl>\n\n";

	return $html;
}

# _entry($manual):
#	One term and one definition. The './' is mandatory: a browser
#	reads a relative URL whose first segment holds a colon as a
#	scheme, and a module page is named App::FuguWeb.3p.html.
sub _entry ($manual)
{
	my $name    = App::FuguWeb::escape_html( $manual->name );
	my $section = $manual->section;

	return
	    sprintf "<dt><a href=\"./%s\">%s(%s)</a></dt>\n" . "<dd>%s</dd>\n",
	    App::FuguWeb::escape_attr( $manual->page ), $name, $section,
	    App::FuguWeb::escape_html( $manual->description );
}

1;
